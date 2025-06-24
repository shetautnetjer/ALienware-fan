#!/bin/bash

# 🔥 Test Unlocked Fan Control
# Tests the newly discovered writable fan control registers

set -e

echo "🔥 Testing Unlocked Fan Control"
echo "==============================="
echo "Date: $(date)"
echo ""

# Function to read fan speed from hwmon6
get_fan_speed() {
    local fan_num="$1"
    cat "/sys/class/hwmon/hwmon6/fan${fan_num}_input" 2>/dev/null || echo "N/A"
}

# Function to read fan label
get_fan_label() {
    local fan_num="$1"
    cat "/sys/class/hwmon/hwmon6/fan${fan_num}_label" 2>/dev/null || echo "Fan $fan_num"
}

# Function to test register control
test_register_control() {
    local register="$1"
    local fan_name="$2"
    local fan_num="$3"
    
    echo "🧪 Testing $fan_name (Register 0x$register, Fan $fan_num)"
    echo "=================================================="
    
    # Get initial fan speed
    initial_speed=$(get_fan_speed "$fan_num")
    echo "Initial fan speed: $initial_speed RPM"
    
    # Test different PWM values
    test_values=(0x00 0x40 0x80 0xC0 0xFF)
    
    for pwm_hex in "${test_values[@]}"; do
        pwm_dec=$((16#$pwm_hex))
        echo ""
        echo "Setting register 0x$register to 0x$pwm_hex ($pwm_dec)..."
        
        # Write to register
        if echo -ne "\x$pwm_hex" | sudo dd of=/dev/port bs=1 count=1 seek=$((0x$register)) 2>/dev/null; then
            echo "  ✅ Register write successful"
            
            # Wait for fan to respond
            sleep 2
            
            # Read back register value
            register_value=$(sudo dd if=/dev/port bs=1 count=1 skip=$((0x$register)) 2>/dev/null | od -An -tu1)
            echo "  Register value: $register_value"
            
            # Get new fan speed
            new_speed=$(get_fan_speed "$fan_num")
            echo "  New fan speed: $new_speed RPM"
            
            # Check if speed changed
            if [[ "$new_speed" != "$initial_speed" && "$new_speed" != "N/A" ]]; then
                echo "  🎉 FAN SPEED CHANGED! Control successful!"
            else
                echo "  ⚠️  Fan speed unchanged"
            fi
        else
            echo "  ❌ Register write failed"
        fi
    done
    
    echo ""
    echo "Test completed for $fan_name"
    echo "----------------------------------------"
}

# Function to test all unlocked fans
test_all_unlocked_fans() {
    echo "🚀 Testing All Unlocked Fans"
    echo "============================"
    
    # Map of registers to fan names and numbers
    declare -A fan_map=(
        ["24"]="GPU Fan:2"
        ["28"]="VRM Fan:3" 
        ["2C"]="Exhaust Fan:4"
        ["30"]="Chassis Fan:1"
        ["34"]="Memory Fan:4"
        ["38"]="Additional Fan 1:1"
        ["3C"]="Additional Fan 2:2"
    )
    
    for register in "${!fan_map[@]}"; do
        fan_info="${fan_map[$register]}"
        fan_name=$(echo "$fan_info" | cut -d: -f1)
        fan_num=$(echo "$fan_info" | cut -d: -f2)
        
        test_register_control "$register" "$fan_name" "$fan_num"
        echo ""
    done
}

# Function to set fan speed
set_fan_speed() {
    local register="$1"
    local pwm_value="$2"
    local fan_name="$3"
    
    echo "Setting $fan_name (Register 0x$register) to PWM $pwm_value..."
    
    # Convert decimal to hex
    pwm_hex=$(printf "%02X" "$pwm_value")
    
    # Write to register
    if echo -ne "\x$pwm_hex" | sudo dd of=/dev/port bs=1 count=1 seek=$((0x$register)) 2>/dev/null; then
        echo "  ✅ $fan_name set to PWM $pwm_value"
        return 0
    else
        echo "  ❌ Failed to set $fan_name"
        return 1
    fi
}

# Function to set all fans to same speed
set_all_fans() {
    local pwm_value="$1"
    local mode_name="$2"
    
    echo "🎛️  Setting All Fans to $mode_name Mode (PWM: $pwm_value)"
    echo "=================================================="
    
    # Set each unlocked fan
    set_fan_speed "24" "$pwm_value" "GPU Fan"
    set_fan_speed "28" "$pwm_value" "VRM Fan"
    set_fan_speed "2C" "$pwm_value" "Exhaust Fan"
    set_fan_speed "30" "$pwm_value" "Chassis Fan"
    set_fan_speed "34" "$pwm_value" "Memory Fan"
    set_fan_speed "38" "$pwm_value" "Additional Fan 1"
    set_fan_speed "3C" "$pwm_value" "Additional Fan 2"
    
    echo ""
    echo "All fans set to $mode_name mode"
}

# Function to show current fan status
show_fan_status() {
    echo "📊 Current Fan Status"
    echo "===================="
    
    echo "hwmon6 Fans (Read-only):"
    for i in {1..4}; do
        speed=$(get_fan_speed "$i")
        label=$(get_fan_label "$i")
        echo "  $label: $speed RPM"
    done
    
    echo ""
    echo "EC Register Status:"
    registers=("20" "24" "28" "2C" "30" "34" "38" "3C")
    names=("CPU" "GPU" "VRM" "Exhaust" "Chassis" "Memory" "Additional1" "Additional2")
    
    for i in "${!registers[@]}"; do
        register="${registers[$i]}"
        name="${names[$i]}"
        value=$(sudo dd if=/dev/port bs=1 count=1 skip=$((0x$register)) 2>/dev/null | od -An -tu1)
        echo "  $name Fan (0x$register): $value"
    done
}

# Function to create fan control presets
create_fan_presets() {
    echo "🎛️  Fan Control Presets"
    echo "======================="
    
    echo "Available presets:"
    echo "  silent    - PWM 32 (12.5%)"
    echo "  quiet     - PWM 64 (25%)"
    echo "  normal    - PWM 128 (50%)"
    echo "  performance - PWM 192 (75%)"
    echo "  max       - PWM 255 (100%)"
    echo "  custom    - Specify PWM value"
    echo ""
    
    read -p "Select preset (or 'custom'): " preset
    
    case $preset in
        silent)
            set_all_fans 32 "Silent"
            ;;
        quiet)
            set_all_fans 64 "Quiet"
            ;;
        normal)
            set_all_fans 128 "Normal"
            ;;
        performance)
            set_all_fans 192 "Performance"
            ;;
        max)
            set_all_fans 255 "Maximum"
            ;;
        custom)
            read -p "Enter PWM value (0-255): " pwm_value
            if [[ $pwm_value -ge 0 && $pwm_value -le 255 ]]; then
                set_all_fans "$pwm_value" "Custom"
            else
                echo "Invalid PWM value"
            fi
            ;;
        *)
            echo "Unknown preset"
            ;;
    esac
}

# Main menu
main_menu() {
    while true; do
        echo ""
        echo "🔥 Alienware Fan Control Menu"
        echo "============================="
        echo "1. Show current fan status"
        echo "2. Test all unlocked fans"
        echo "3. Set fan presets"
        echo "4. Set individual fan"
        echo "5. Set all fans to same speed"
        echo "6. Exit"
        echo ""
        
        read -p "Select option (1-6): " choice
        
        case $choice in
            1)
                show_fan_status
                ;;
            2)
                test_all_unlocked_fans
                ;;
            3)
                create_fan_presets
                ;;
            4)
                echo "Available fans:"
                echo "  24 - GPU Fan"
                echo "  28 - VRM Fan"
                echo "  2C - Exhaust Fan"
                echo "  30 - Chassis Fan"
                echo "  34 - Memory Fan"
                echo "  38 - Additional Fan 1"
                echo "  3C - Additional Fan 2"
                echo ""
                read -p "Enter register (hex): " register
                read -p "Enter PWM value (0-255): " pwm_value
                if [[ $pwm_value -ge 0 && $pwm_value -le 255 ]]; then
                    set_fan_speed "$register" "$pwm_value" "Selected Fan"
                else
                    echo "Invalid PWM value"
                fi
                ;;
            5)
                read -p "Enter PWM value (0-255): " pwm_value
                if [[ $pwm_value -ge 0 && $pwm_value -le 255 ]]; then
                    set_all_fans "$pwm_value" "Custom"
                else
                    echo "Invalid PWM value"
                fi
                ;;
            6)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script requires root privileges"
    echo "Run with: sudo $0"
    exit 1
fi

# Check if /dev/port is accessible
if [[ ! -r /dev/port ]]; then
    echo "❌ Cannot access /dev/port"
    exit 1
fi

# Show initial status
show_fan_status

# Run main menu
main_menu 