#!/bin/bash

# 🔥 Alienware Enhanced Fan Control
# Controls all 9 fans: 3 hwmon7 + 6 EC-controlled fans

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../gui_config.json"
LOG_FILE="/tmp/alienfan_control.log"

# Fan control registers (EC-controlled fans)
EC_FAN_REGISTERS=(
    "24:GPU Fan"
    "28:VRM Fan"
    "2C:Exhaust Fan"
    "30:Chassis Fan"
    "34:Memory Fan"
    "38:Additional Fan 1"
    "3C:Additional Fan 2"
)

# hwmon7 fans (original controllable fans)
HWMON7_FANS=(1 2 3)

# Temperature sensors
TEMP_SENSORS=(
    "/sys/class/thermal/thermal_zone0/temp"
    "/sys/class/thermal/thermal_zone1/temp"
    "/sys/class/thermal/thermal_zone2/temp"
    "/sys/class/thermal/thermal_zone3/temp"
    "/sys/class/thermal/thermal_zone4/temp"
    "/sys/class/thermal/thermal_zone5/temp"
    "/sys/class/thermal/thermal_zone6/temp"
    "/sys/class/thermal/thermal_zone7/temp"
)

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ This script requires root privileges"
        echo "Run with: sudo $0"
        exit 1
    fi
}

# Function to check if /dev/port is accessible
check_ec_access() {
    if [[ ! -r /dev/port ]]; then
        echo "❌ Cannot access /dev/port"
        echo "EC fan control will be disabled"
        return 1
    fi
    return 0
}

# Function to set EC fan speed
set_ec_fan() {
    local register="$1"
    local pwm_value="$2"
    local fan_name="$3"
    
    # Convert decimal to hex
    local pwm_hex=$(printf "%02X" "$pwm_value")
    
    # Write to EC register
    if echo -ne "\x$pwm_hex" | dd of=/dev/port bs=1 count=1 seek=$((0x$register)) 2>/dev/null; then
        log_message "Set $fan_name (EC 0x$register) to PWM $pwm_value"
        return 0
    else
        log_message "Failed to set $fan_name (EC 0x$register) to PWM $pwm_value"
        return 1
    fi
}

# Function to set hwmon7 fan speed
set_hwmon7_fan() {
    local fan_num="$1"
    local pwm_value="$2"
    
    local pwm_file="/sys/class/hwmon/hwmon7/pwm$fan_num"
    
    if [[ -w "$pwm_file" ]]; then
        echo "$pwm_value" > "$pwm_file" 2>/dev/null
        log_message "Set hwmon7 Fan $fan_num to PWM $pwm_value"
        return 0
    else
        log_message "Failed to set hwmon7 Fan $fan_num to PWM $pwm_value"
        return 1
    fi
}

# Function to get current temperature
get_current_temp() {
    local max_temp=0
    
    for sensor in "${TEMP_SENSORS[@]}"; do
        if [[ -r "$sensor" ]]; then
            local temp=$(cat "$sensor" 2>/dev/null || echo "0")
            temp=$((temp / 1000))  # Convert from millidegrees
            if [[ $temp -gt $max_temp ]]; then
                max_temp=$temp
            fi
        fi
    done
    
    echo "$max_temp"
}

# Function to set all fans based on mode
set_fan_mode() {
    local mode="$1"
    local pwm_value=0
    
    case $mode in
        silent)
            pwm_value=32  # 12.5%
            mode_name="Silent"
            ;;
        quiet)
            pwm_value=64  # 25%
            mode_name="Quiet"
            ;;
        normal)
            pwm_value=128  # 50%
            mode_name="Normal"
            ;;
        performance)
            pwm_value=192  # 75%
            mode_name="Performance"
            ;;
        max)
            pwm_value=255  # 100%
            mode_name="Maximum"
            ;;
        gaming)
            pwm_value=200  # 78%
            mode_name="Gaming"
            ;;
        stress)
            pwm_value=240  # 94%
            mode_name="Stress Test"
            ;;
        *)
            echo "❌ Unknown mode: $mode"
            echo "Available modes: silent, quiet, normal, performance, max, gaming, stress"
            return 1
            ;;
    esac
    
    log_message "Setting all fans to $mode_name mode (PWM: $pwm_value)"
    
    # Set EC-controlled fans
    for fan_info in "${EC_FAN_REGISTERS[@]}"; do
        register=$(echo "$fan_info" | cut -d: -f1)
        fan_name=$(echo "$fan_info" | cut -d: -f2)
        set_ec_fan "$register" "$pwm_value" "$fan_name"
    done
    
    # Set hwmon7 fans
    for fan_num in "${HWMON7_FANS[@]}"; do
        set_hwmon7_fan "$fan_num" "$pwm_value"
    done
    
    echo "✅ All fans set to $mode_name mode"
}

# Function to set individual fan
set_individual_fan() {
    local fan_type="$1"
    local fan_id="$2"
    local pwm_value="$3"
    
    if [[ $pwm_value -lt 0 || $pwm_value -gt 255 ]]; then
        echo "❌ PWM value must be between 0 and 255"
        return 1
    fi
    
    case $fan_type in
        ec)
            # Find fan by register
            for fan_info in "${EC_FAN_REGISTERS[@]}"; do
                register=$(echo "$fan_info" | cut -d: -f1)
                fan_name=$(echo "$fan_info" | cut -d: -f2)
                if [[ "$register" == "$fan_id" ]]; then
                    set_ec_fan "$register" "$pwm_value" "$fan_name"
                    return 0
                fi
            done
            echo "❌ Unknown EC fan: $fan_id"
            ;;
        hwmon7)
            if [[ "$fan_id" =~ ^[1-3]$ ]]; then
                set_hwmon7_fan "$fan_id" "$pwm_value"
            else
                echo "❌ Invalid hwmon7 fan: $fan_id (must be 1-3)"
            fi
            ;;
        *)
            echo "❌ Unknown fan type: $fan_type (use 'ec' or 'hwmon7')"
            ;;
    esac
}

# Function to set temperature-based control
set_temp_based_control() {
    local target_temp="$1"
    local max_pwm="$2"
    
    if [[ -z "$target_temp" ]]; then
        target_temp=80
    fi
    if [[ -z "$max_pwm" ]]; then
        max_pwm=255
    fi
    
    log_message "Starting temperature-based control (target: ${target_temp}°C, max PWM: $max_pwm)"
    
    echo "🌡️  Temperature-based fan control active"
    echo "Target temperature: ${target_temp}°C"
    echo "Maximum PWM: $max_pwm"
    echo "Press Ctrl+C to stop"
    
    while true; do
        current_temp=$(get_current_temp)
        echo -ne "\rCurrent temperature: ${current_temp}°C"
        
        if [[ $current_temp -gt $target_temp ]]; then
            # Calculate PWM based on temperature difference
            temp_diff=$((current_temp - target_temp))
            pwm_value=$((max_pwm * temp_diff / 20))  # Scale based on 20°C range
            
            # Clamp PWM value
            if [[ $pwm_value -gt $max_pwm ]]; then
                pwm_value=$max_pwm
            fi
            if [[ $pwm_value -lt 64 ]]; then
                pwm_value=64  # Minimum 25%
            fi
            
            # Set all fans
            for fan_info in "${EC_FAN_REGISTERS[@]}"; do
                register=$(echo "$fan_info" | cut -d: -f1)
                fan_name=$(echo "$fan_info" | cut -d: -f2)
                set_ec_fan "$register" "$pwm_value" "$fan_name" >/dev/null
            done
            
            for fan_num in "${HWMON7_FANS[@]}"; do
                set_hwmon7_fan "$fan_num" "$pwm_value" >/dev/null
            done
            
            echo -n " (PWM: $pwm_value)"
        else
            # Set to minimum speed
            for fan_info in "${EC_FAN_REGISTERS[@]}"; do
                register=$(echo "$fan_info" | cut -d: -f1)
                fan_name=$(echo "$fan_info" | cut -d: -f2)
                set_ec_fan "$register" "64" "$fan_name" >/dev/null
            done
            
            for fan_num in "${HWMON7_FANS[@]}"; do
                set_hwmon7_fan "$fan_num" "64" >/dev/null
            done
            
            echo -n " (PWM: 64)"
        fi
        
        sleep 5
    done
}

# Function to show fan status
show_fan_status() {
    echo "📊 Fan Status"
    echo "============="
    
    echo "EC-Controlled Fans:"
    for fan_info in "${EC_FAN_REGISTERS[@]}"; do
        register=$(echo "$fan_info" | cut -d: -f1)
        fan_name=$(echo "$fan_info" | cut -d: -f2)
        value=$(dd if=/dev/port bs=1 count=1 skip=$((0x$register)) 2>/dev/null | od -An -tu1)
        echo "  $fan_name (0x$register): PWM $value"
    done
    
    echo ""
    echo "hwmon7 Fans:"
    for fan_num in "${HWMON7_FANS[@]}"; do
        pwm_file="/sys/class/hwmon/hwmon7/pwm$fan_num"
        if [[ -r "$pwm_file" ]]; then
            pwm_value=$(cat "$pwm_file" 2>/dev/null || echo "N/A")
            fan_input="/sys/class/hwmon/hwmon7/fan${fan_num}_input"
            if [[ -r "$fan_input" ]]; then
                rpm=$(cat "$fan_input" 2>/dev/null || echo "N/A")
                echo "  Fan $fan_num: PWM $pwm_value, RPM $rpm"
            else
                echo "  Fan $fan_num: PWM $pwm_value"
            fi
        else
            echo "  Fan $fan_num: Not accessible"
        fi
    done
    
    echo ""
    echo "hwmon6 Fans (Read-only):"
    for i in {1..4}; do
        fan_input="/sys/class/hwmon/hwmon6/fan${i}_input"
        fan_label="/sys/class/hwmon/hwmon6/fan${i}_label"
        if [[ -r "$fan_input" ]]; then
            rpm=$(cat "$fan_input" 2>/dev/null || echo "N/A")
            label=$(cat "$fan_label" 2>/dev/null || echo "Fan $i")
            echo "  $label: $rpm RPM"
        fi
    done
    
    echo ""
    echo "Temperature: $(get_current_temp)°C"
}

# Function to show available fans
show_available_fans() {
    echo "🎛️  Available Fans"
    echo "=================="
    
    echo "EC-Controlled Fans:"
    for fan_info in "${EC_FAN_REGISTERS[@]}"; do
        register=$(echo "$fan_info" | cut -d: -f1)
        fan_name=$(echo "$fan_info" | cut -d: -f2)
        echo "  $fan_name (register: 0x$register)"
    done
    
    echo ""
    echo "hwmon7 Fans:"
    for fan_num in "${HWMON7_FANS[@]}"; do
        echo "  Fan $fan_num (PWM file: /sys/class/hwmon/hwmon7/pwm$fan_num)"
    done
}

# Function to restore BIOS control
restore_bios_control() {
    log_message "Restoring BIOS fan control"
    
    # Set all fans to auto mode (PWM 0)
    for fan_info in "${EC_FAN_REGISTERS[@]}"; do
        register=$(echo "$fan_info" | cut -d: -f1)
        fan_name=$(echo "$fan_info" | cut -d: -f2)
        set_ec_fan "$register" "0" "$fan_name"
    done
    
    for fan_num in "${HWMON7_FANS[@]}"; do
        set_hwmon7_fan "$fan_num" "0"
    done
    
    echo "✅ BIOS fan control restored"
}

# Main function
main() {
    local command="$1"
    local arg1="$2"
    local arg2="$3"
    local arg3="$4"
    
    # Check root privileges
    check_root
    
    # Check EC access
    EC_ACCESS=$(check_ec_access)
    
    case $command in
        mode)
            if [[ -z "$arg1" ]]; then
                echo "❌ Mode not specified"
                echo "Available modes: silent, quiet, normal, performance, max, gaming, stress"
                exit 1
            fi
            set_fan_mode "$arg1"
            ;;
        individual)
            if [[ -z "$arg1" || -z "$arg2" || -z "$arg3" ]]; then
                echo "❌ Usage: $0 individual <type> <id> <pwm>"
                echo "Types: ec (register), hwmon7 (fan number)"
                echo "Example: $0 individual ec 24 128"
                echo "Example: $0 individual hwmon7 1 192"
                exit 1
            fi
            set_individual_fan "$arg1" "$arg2" "$arg3"
            ;;
        temp)
            set_temp_based_control "$arg1" "$arg2"
            ;;
        status)
            show_fan_status
            ;;
        fans)
            show_available_fans
            ;;
        restore)
            restore_bios_control
            ;;
        test)
            echo "🧪 Testing all fans..."
            echo "Setting to 50% for 5 seconds..."
            set_fan_mode "normal"
            sleep 5
            echo "Setting to 75% for 5 seconds..."
            set_fan_mode "performance"
            sleep 5
            echo "Setting to 100% for 5 seconds..."
            set_fan_mode "max"
            sleep 5
            echo "Restoring BIOS control..."
            restore_bios_control
            echo "✅ Test completed"
            ;;
        *)
            echo "🔥 Alienware Enhanced Fan Control"
            echo "================================="
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  mode <mode>                    Set all fans to mode"
            echo "    Modes: silent, quiet, normal, performance, max, gaming, stress"
            echo ""
            echo "  individual <type> <id> <pwm>  Set individual fan"
            echo "    Types: ec (register), hwmon7 (fan number)"
            echo "    Example: $0 individual ec 24 128"
            echo "    Example: $0 individual hwmon7 1 192"
            echo ""
            echo "  temp [target_temp] [max_pwm]  Temperature-based control"
            echo "    Default: target 80°C, max PWM 255"
            echo ""
            echo "  status                         Show current fan status"
            echo "  fans                           Show available fans"
            echo "  test                           Test all fans"
            echo "  restore                        Restore BIOS control"
            echo ""
            echo "Examples:"
            echo "  $0 mode performance"
            echo "  $0 mode max"
            echo "  $0 individual ec 24 128"
            echo "  $0 temp 75 200"
            echo "  $0 status"
            ;;
    esac
}

# Run main function
main "$@" 