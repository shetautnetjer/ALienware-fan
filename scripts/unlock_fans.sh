#!/bin/bash

# 🔥 Alienware Fan Unlock Script
# Attempts to unlock additional fan control from BIOS restrictions

set -e

echo "🔥 Alienware Fan Unlock Attempt"
echo "==============================="
echo "Date: $(date)"
echo ""

# Function to check if a file exists and is readable
file_exists() {
    [[ -r "$1" ]]
}

# Function to check if a file is writable
file_writable() {
    [[ -w "$1" ]]
}

# Function to test PWM control
test_pwm_control() {
    local hwmon_path="$1"
    local pwm_num="$2"
    local pwm_file="$hwmon_path/pwm$pwm_num"
    
    if file_exists "$pwm_file"; then
        echo "  Testing PWM$pwm_num control..."
        current_pwm=$(cat "$pwm_file" 2>/dev/null || echo "0")
        echo "    Current PWM: $current_pwm"
        
        if file_writable "$pwm_file"; then
            echo "    Testing PWM write..."
            echo "128" > "$pwm_file" 2>/dev/null && echo "    ✅ PWM write successful" || echo "    ❌ PWM write failed"
            
            new_pwm=$(cat "$pwm_file" 2>/dev/null || echo "0")
            echo "    New PWM: $new_pwm"
            
            # Restore original
            echo "$current_pwm" > "$pwm_file" 2>/dev/null
        else
            echo "    ❌ PWM file not writable"
        fi
    fi
}

# Function to check EC ports
check_ec_ports() {
    echo "🔌 Checking EC ports for additional fan control..."
    
    # Common EC ports for fan control
    ec_ports=(0x62 0x66 0x80 0x84 0x88 0x8C 0x90 0x94 0x98 0x9C)
    
    for port in "${ec_ports[@]}"; do
        echo "  Testing EC port 0x$port..."
        if timeout 1 dd if=/dev/port bs=1 count=1 skip=$((0x$port)) 2>/dev/null; then
            echo "    ✅ Port 0x$port accessible"
        else
            echo "    ❌ Port 0x$port not accessible"
        fi
    done
    echo ""
}

# Function to try different dell-smm-hwmon parameters
try_dell_smm_parameters() {
    echo "🔧 Trying different dell-smm-hwmon parameters..."
    
    # Unload current module
    sudo modprobe -r dell-smm-hwmon 2>/dev/null || true
    sleep 1
    
    # Test different parameter combinations
    param_combinations=(
        "force=1"
        "force=1 ignore_dmi=1"
        "force=1 ignore_dmi=1 restricted=0"
        "force=1 ignore_dmi=1 restricted=0 fan_mult=1"
        "force=1 ignore_dmi=1 restricted=0 fan_div=1"
        "force=1 ignore_dmi=1 restricted=0 power_status=1"
        "force=1 ignore_dmi=1 restricted=0 fan_mult=1 fan_div=1"
    )
    
    for params in "${param_combinations[@]}"; do
        echo "  Testing parameters: $params"
        
        # Load module with parameters
        if sudo modprobe dell-smm-hwmon $params 2>/dev/null; then
            echo "    ✅ Module loaded successfully"
            sleep 2
            
            # Check for PWM files
            pwm_files=$(find /sys/class/hwmon/ -name "*pwm*" 2>/dev/null | wc -l)
            echo "    Found $pwm_files PWM files"
            
            if [[ $pwm_files -gt 0 ]]; then
                echo "    PWM files found:"
                find /sys/class/hwmon/ -name "*pwm*" 2>/dev/null | while read file; do
                    echo "      $file"
                done
            fi
            
            # Test PWM control
            for hwmon_dir in /sys/class/hwmon/hwmon*; do
                if [[ -d "$hwmon_dir" ]]; then
                    hwmon_name=$(basename "$hwmon_dir")
                    for pwm_file in "$hwmon_dir"/pwm*; do
                        if [[ -f "$pwm_file" ]]; then
                            pwm_num=$(basename "$pwm_file" | sed 's/pwm\([0-9]*\)/\1/')
                            test_pwm_control "$hwmon_dir" "$pwm_num"
                        fi
                    done
                fi
            done
            
            # Unload for next test
            sudo modprobe -r dell-smm-hwmon 2>/dev/null || true
            sleep 1
        else
            echo "    ❌ Failed to load module"
        fi
        echo ""
    done
}

# Function to try ACPI methods
try_acpi_methods() {
    echo "📋 Trying ACPI methods for fan control..."
    
    # Common ACPI methods for fan control
    acpi_methods=(
        "_SB.PCI0.LPCB.EC.FAN"
        "_SB.PCI0.LPCB.EC.FAN1"
        "_SB.PCI0.LPCB.EC.FAN2"
        "_SB.PCI0.LPCB.EC.FAN3"
        "_SB.PCI0.LPCB.EC.FAN4"
        "_SB.PCI0.LPCB.EC.SFAN"
        "_SB.PCI0.LPCB.EC.CFAN"
        "_SB.PCI0.LPCB.EC.PFAN"
        "_SB.PCI0.LPCB.EC.FAN_CTL"
        "_SB.PCI0.LPCB.EC.FAN_SPEED"
    )
    
    for method in "${acpi_methods[@]}"; do
        echo "  Testing ACPI method: $method"
        if acpi_call -p "$method" 2>/dev/null; then
            echo "    ✅ Method exists and callable"
        else
            echo "    ❌ Method not available"
        fi
    done
    echo ""
}

# Function to try direct EC access
try_direct_ec_access() {
    echo "🔌 Trying direct EC access for fan control..."
    
    # Check if we can access EC ports
    if [[ -r /dev/port ]]; then
        echo "  ✅ /dev/port accessible"
        
        # Try to read EC data
        echo "  Reading EC data..."
        for i in {0..255}; do
            if timeout 1 dd if=/dev/port bs=1 count=1 skip=$i 2>/dev/null > /tmp/ec_byte_$i; then
                echo "    EC byte $i: $(od -An -tu1 /tmp/ec_byte_$i 2>/dev/null)"
            fi
        done
        
        # Clean up
        rm -f /tmp/ec_byte_*
    else
        echo "  ❌ /dev/port not accessible"
    fi
    echo ""
}

# Function to try kernel module hacking
try_kernel_hacking() {
    echo "🔧 Trying kernel module hacking..."
    
    # Check if dell-smm-hwmon is loaded
    if lsmod | grep -q dell_smm_hwmon; then
        echo "  ✅ dell-smm-hwmon module loaded"
        
        # Try to modify module parameters at runtime
        echo "  Attempting to modify module parameters..."
        
        # Check available parameters
        if [[ -d /sys/module/dell_smm_hwmon/parameters ]]; then
            echo "  Available parameters:"
            ls /sys/module/dell_smm_hwmon/parameters/ | while read param; do
                value=$(cat "/sys/module/dell_smm_hwmon/parameters/$param" 2>/dev/null || echo "N/A")
                echo "    $param: $value"
            done
        fi
    else
        echo "  ❌ dell-smm-hwmon module not loaded"
    fi
    echo ""
}

# Function to try firmware interface
try_firmware_interface() {
    echo "💾 Trying firmware interface..."
    
    # Check for firmware interfaces
    if [[ -d /sys/firmware/dmi ]]; then
        echo "  ✅ DMI firmware interface available"
        
        # Try to read DMI data
        echo "  Reading DMI data..."
        if command -v dmidecode >/dev/null 2>&1; then
            dmidecode -t 39 2>/dev/null | head -20 || echo "    No thermal data found"
        fi
    fi
    
    if [[ -d /sys/firmware/efi ]]; then
        echo "  ✅ EFI firmware interface available"
    fi
    
    echo ""
}

# Function to try thermal zone manipulation
try_thermal_zones() {
    echo "🌡️  Trying thermal zone manipulation..."
    
    # Check thermal zones
    if [[ -d /sys/class/thermal ]]; then
        echo "  Available thermal zones:"
        for zone in /sys/class/thermal/thermal_zone*; do
            if [[ -d "$zone" ]]; then
                zone_num=$(basename "$zone" | sed 's/thermal_zone//')
                temp=$(cat "$zone/temp" 2>/dev/null || echo "N/A")
                type=$(cat "$zone/type" 2>/dev/null || echo "Unknown")
                echo "    Zone $zone_num ($type): ${temp}°C"
            fi
        done
        
        # Try to modify thermal policies
        echo "  Attempting to modify thermal policies..."
        for zone in /sys/class/thermal/thermal_zone*; do
            if [[ -d "$zone" ]]; then
                zone_num=$(basename "$zone" | sed 's/thermal_zone//')
                if [[ -w "$zone/policy" ]]; then
                    echo "    Zone $zone_num: policy writable"
                fi
            fi
        done
    else
        echo "  ❌ No thermal zones found"
    fi
    echo ""
}

# Function to try power management
try_power_management() {
    echo "⚡ Trying power management interface..."
    
    # Check power management interfaces
    if [[ -d /sys/class/power_supply ]]; then
        echo "  Power supplies:"
        for supply in /sys/class/power_supply/*; do
            if [[ -d "$supply" ]]; then
                supply_name=$(basename "$supply")
                echo "    $supply_name"
            fi
        done
    fi
    
    # Check CPU frequency scaling
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        echo "  CPU frequency scaling available"
        
        # Try to set performance governor
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
            if [[ -d "$cpu" ]]; then
                cpu_num=$(echo "$cpu" | sed 's/.*cpu\([0-9]*\).*/\1/')
                if [[ -w "$cpu/scaling_governor" ]]; then
                    echo "    CPU $cpu_num: governor writable"
                fi
            fi
        done
    fi
    echo ""
}

# Main execution
main() {
    echo "🚀 Starting fan unlock attempts..."
    echo ""
    
    # Method 1: Try different dell-smm-hwmon parameters
    try_dell_smm_parameters
    
    # Method 2: Check EC ports
    check_ec_ports
    
    # Method 3: Try ACPI methods
    try_acpi_methods
    
    # Method 4: Try direct EC access
    try_direct_ec_access
    
    # Method 5: Try kernel module hacking
    try_kernel_hacking
    
    # Method 6: Try firmware interface
    try_firmware_interface
    
    # Method 7: Try thermal zone manipulation
    try_thermal_zones
    
    # Method 8: Try power management
    try_power_management
    
    echo "📋 UNLOCK SUMMARY"
    echo "================="
    echo "Attempted methods:"
    echo "1. dell-smm-hwmon parameter variations"
    echo "2. EC port access"
    echo "3. ACPI method calls"
    echo "4. Direct EC access"
    echo "5. Kernel module hacking"
    echo "6. Firmware interface"
    echo "7. Thermal zone manipulation"
    echo "8. Power management"
    echo ""
    
    echo "🎯 RECOMMENDATIONS"
    echo "=================="
    echo "If additional fan control was unlocked:"
    echo "1. Test the new PWM controls"
    echo "2. Update fan control scripts"
    echo "3. Modify GUI to include new fans"
    echo "4. Document the successful method"
    echo ""
    
    echo "If no additional control was unlocked:"
    echo "1. Try BIOS settings (disable thermal management)"
    echo "2. Investigate EC firmware"
    echo "3. Consider hardware modifications"
    echo "4. Research vendor-specific tools"
    echo ""
    
    echo "🔥 Fan unlock attempts completed!"
}

# Run main function
main "$@" 