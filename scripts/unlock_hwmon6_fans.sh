#!/bin/bash

# 🔥 Alienware hwmon6 Fan Unlock Script
# Attempts to unlock control of the read-only fans on hwmon6

set -e

echo "🔥 Alienware hwmon6 Fan Unlock"
echo "==============================="
echo "Target: CPU Fan, Video Fan, Chassis Fan, Memory Fan"
echo "Date: $(date)"
echo ""

# Function to check current hwmon6 status
check_hwmon6_status() {
    echo "📊 Current hwmon6 Status"
    echo "========================"
    
    if [[ ! -d "/sys/class/hwmon/hwmon6" ]]; then
        echo "❌ hwmon6 not found"
        return 1
    fi
    
    echo "✅ hwmon6 found"
    echo "Device name: $(cat /sys/class/hwmon/hwmon6/name 2>/dev/null || echo 'Unknown')"
    echo ""
    
    echo "Fan Status:"
    for i in {1..4}; do
        if [[ -r "/sys/class/hwmon/hwmon6/fan${i}_input" ]]; then
            rpm=$(cat "/sys/class/hwmon/hwmon6/fan${i}_input")
            label=$(cat "/sys/class/hwmon/hwmon6/fan${i}_label" 2>/dev/null || echo "Fan $i")
            echo "  $label: $rpm RPM"
        fi
    done
    echo ""
    
    echo "PWM Control Status:"
    for i in {1..4}; do
        if [[ -r "/sys/class/hwmon/hwmon6/pwm${i}" ]]; then
            pwm=$(cat "/sys/class/hwmon/hwmon6/pwm${i}")
            if [[ -w "/sys/class/hwmon/hwmon6/pwm${i}" ]]; then
                echo "  PWM$i: $pwm (writable)"
            else
                echo "  PWM$i: $pwm (read-only)"
            fi
        else
            echo "  PWM$i: Not found"
        fi
    done
    echo ""
}

# Function to try creating PWM files
try_create_pwm_files() {
    echo "🔧 Attempting to create PWM control files..."
    
    # Check if we can write to hwmon6 directory
    if [[ -w "/sys/class/hwmon/hwmon6" ]]; then
        echo "✅ hwmon6 directory is writable"
        
        # Try to create PWM files
        for i in {1..4}; do
            echo "  Creating PWM$i..."
            if echo "128" > "/sys/class/hwmon/hwmon6/pwm${i}" 2>/dev/null; then
                echo "    ✅ PWM$i created and writable"
            else
                echo "    ❌ Failed to create PWM$i"
            fi
        done
    else
        echo "❌ hwmon6 directory not writable"
    fi
    echo ""
}

# Function to try module parameter manipulation
try_module_parameters() {
    echo "🔧 Trying module parameter manipulation..."
    
    # Check if dell-smm-hwmon is loaded
    if lsmod | grep -q dell_smm_hwmon; then
        echo "✅ dell-smm-hwmon module loaded"
        
        # Try to modify parameters at runtime
        if [[ -w "/sys/module/dell_smm_hwmon/parameters/force" ]]; then
            echo "  Setting force=1..."
            echo "1" > "/sys/module/dell_smm_hwmon/parameters/force" 2>/dev/null && echo "    ✅ force=1 set" || echo "    ❌ Failed to set force"
        fi
        
        if [[ -w "/sys/module/dell_smm_hwmon/parameters/ignore_dmi" ]]; then
            echo "  Setting ignore_dmi=1..."
            echo "1" > "/sys/module/dell_smm_hwmon/parameters/ignore_dmi" 2>/dev/null && echo "    ✅ ignore_dmi=1 set" || echo "    ❌ Failed to set ignore_dmi"
        fi
        
        if [[ -w "/sys/module/dell_smm_hwmon/parameters/restricted" ]]; then
            echo "  Setting restricted=0..."
            echo "0" > "/sys/module/dell_smm_hwmon/parameters/restricted" 2>/dev/null && echo "    ✅ restricted=0 set" || echo "    ❌ Failed to set restricted"
        fi
    else
        echo "❌ dell-smm-hwmon module not loaded"
    fi
    echo ""
}

# Function to try EC register manipulation
try_ec_registers() {
    echo "🔌 Trying EC register manipulation..."
    
    # Check if we can access EC ports
    if [[ -r /dev/port ]]; then
        echo "✅ /dev/port accessible"
        
        # Common EC registers for fan control
        ec_registers=(
            "0x62:0x00"  # EC command port
            "0x62:0x01"  # EC data port
            "0x66:0x00"  # SMM command port
            "0x66:0x01"  # SMM data port
        )
        
        for reg in "${ec_registers[@]}"; do
            port=$(echo "$reg" | cut -d: -f1)
            offset=$(echo "$reg" | cut -d: -f2)
            echo "  Testing EC register $reg..."
            
            # Try to read the register
            if timeout 1 dd if=/dev/port bs=1 count=1 skip=$((0x$port)) 2>/dev/null > /tmp/ec_read; then
                value=$(od -An -tu1 /tmp/ec_read 2>/dev/null)
                echo "    Port $port: $value"
                
                # Try to write to the register
                echo "    Attempting write..."
                if echo -ne "\x80" | sudo dd of=/dev/port bs=1 count=1 seek=$((0x$port)) 2>/dev/null; then
                    echo "    ✅ Write successful"
                else
                    echo "    ❌ Write failed"
                fi
            else
                echo "    ❌ Read failed"
            fi
        done
        
        rm -f /tmp/ec_read
    else
        echo "❌ /dev/port not accessible"
    fi
    echo ""
}

# Function to try ACPI method calls
try_acpi_methods() {
    echo "📋 Trying ACPI method calls..."
    
    # Check if acpi_call is available
    if command -v acpi_call >/dev/null 2>&1; then
        echo "✅ acpi_call available"
        
        # Try specific ACPI methods for hwmon6 fans
        acpi_methods=(
            "_SB.PCI0.LPCB.EC.FAN1"
            "_SB.PCI0.LPCB.EC.FAN2"
            "_SB.PCI0.LPCB.EC.FAN3"
            "_SB.PCI0.LPCB.EC.FAN4"
            "_SB.PCI0.LPCB.EC.SFAN"
            "_SB.PCI0.LPCB.EC.CFAN"
            "_SB.PCI0.LPCB.EC.PFAN"
            "_SB.PCI0.LPCB.EC.FAN_CTL"
        )
        
        for method in "${acpi_methods[@]}"; do
            echo "  Testing ACPI method: $method"
            if acpi_call -p "$method" 2>/dev/null; then
                echo "    ✅ Method exists"
                
                # Try to call with parameters
                echo "    Attempting to call with parameters..."
                if acpi_call -p "$method" -i 128 2>/dev/null; then
                    echo "    ✅ Method call successful"
                else
                    echo "    ❌ Method call failed"
                fi
            else
                echo "    ❌ Method not available"
            fi
        done
    else
        echo "❌ acpi_call not available"
        echo "  Install with: sudo apt install acpi-call-dkms"
    fi
    echo ""
}

# Function to try kernel module reloading
try_module_reload() {
    echo "🔄 Trying kernel module reloading..."
    
    # Unload dell-smm-hwmon
    echo "  Unloading dell-smm-hwmon..."
    sudo modprobe -r dell-smm-hwmon 2>/dev/null || echo "    Module not loaded"
    sleep 2
    
    # Try different parameter combinations
    param_combinations=(
        "force=1"
        "force=1 ignore_dmi=1"
        "force=1 ignore_dmi=1 restricted=0"
        "force=1 ignore_dmi=1 restricted=0 fan_mult=1"
        "force=1 ignore_dmi=1 restricted=0 fan_div=1"
        "force=1 ignore_dmi=1 restricted=0 power_status=1"
    )
    
    for params in "${param_combinations[@]}"; do
        echo "  Loading with parameters: $params"
        
        if sudo modprobe dell-smm-hwmon $params 2>/dev/null; then
            echo "    ✅ Module loaded successfully"
            sleep 2
            
            # Check if hwmon6 PWM files are now writable
            pwm_writable=0
            for i in {1..4}; do
                if [[ -w "/sys/class/hwmon/hwmon6/pwm${i}" ]]; then
                    ((pwm_writable++))
                fi
            done
            
            if [[ $pwm_writable -gt 0 ]]; then
                echo "    🎉 SUCCESS: $pwm_writable PWM files are now writable!"
                echo "    Parameters that worked: $params"
                return 0
            else
                echo "    ❌ No PWM files writable"
            fi
            
            # Unload for next test
            sudo modprobe -r dell-smm-hwmon 2>/dev/null
            sleep 1
        else
            echo "    ❌ Failed to load module"
        fi
    done
    echo ""
}

# Function to try thermal policy manipulation
try_thermal_policy() {
    echo "🌡️  Trying thermal policy manipulation..."
    
    # Check thermal zones
    if [[ -d /sys/class/thermal ]]; then
        echo "✅ Thermal zones available"
        
        # Try to modify thermal policies
        for zone in /sys/class/thermal/thermal_zone*; do
            if [[ -d "$zone" ]]; then
                zone_num=$(basename "$zone" | sed 's/thermal_zone//')
                echo "  Zone $zone_num:"
                
                # Check if policy is writable
                if [[ -w "$zone/policy" ]]; then
                    echo "    Policy writable"
                    
                    # Try to set performance policy
                    if echo "performance" > "$zone/policy" 2>/dev/null; then
                        echo "    ✅ Performance policy set"
                    else
                        echo "    ❌ Failed to set performance policy"
                    fi
                else
                    echo "    Policy not writable"
                fi
                
                # Check if cdev is writable
                for cdev in "$zone"/cdev*; do
                    if [[ -d "$cdev" ]]; then
                        cdev_num=$(basename "$cdev" | sed 's/cdev//')
                        if [[ -w "$cdev/cur_state" ]]; then
                            echo "    Cooling device $cdev_num writable"
                        fi
                    fi
                done
            fi
        done
    else
        echo "❌ No thermal zones found"
    fi
    echo ""
}

# Function to try power management
try_power_management() {
    echo "⚡ Trying power management manipulation..."
    
    # Check CPU frequency scaling
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        echo "✅ CPU frequency scaling available"
        
        # Try to set performance governor
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
            if [[ -d "$cpu" ]]; then
                cpu_num=$(echo "$cpu" | sed 's/.*cpu\([0-9]*\).*/\1/')
                if [[ -w "$cpu/scaling_governor" ]]; then
                    echo "  CPU $cpu_num: Setting performance governor..."
                    if echo "performance" > "$cpu/scaling_governor" 2>/dev/null; then
                        echo "    ✅ Performance governor set"
                    else
                        echo "    ❌ Failed to set performance governor"
                    fi
                fi
            fi
        done
    fi
    
    # Check power supply
    if [[ -d /sys/class/power_supply ]]; then
        echo "✅ Power supplies available"
        
        for supply in /sys/class/power_supply/*; do
            if [[ -d "$supply" ]]; then
                supply_name=$(basename "$supply")
                echo "  Power supply: $supply_name"
                
                # Check if charge control is available
                if [[ -w "$supply/charge_control_start_threshold" ]]; then
                    echo "    Charge control writable"
                fi
            fi
        done
    fi
    echo ""
}

# Function to test PWM control after unlock attempts
test_pwm_control() {
    echo "🧪 Testing PWM control after unlock attempts..."
    
    if [[ ! -d "/sys/class/hwmon/hwmon6" ]]; then
        echo "❌ hwmon6 not found"
        return 1
    fi
    
    pwm_writable=0
    for i in {1..4}; do
        if [[ -w "/sys/class/hwmon/hwmon6/pwm${i}" ]]; then
            echo "  PWM$i: Testing control..."
            
            # Read current value
            current_pwm=$(cat "/sys/class/hwmon/hwmon6/pwm${i}" 2>/dev/null || echo "0")
            echo "    Current PWM: $current_pwm"
            
            # Test write
            if echo "128" > "/sys/class/hwmon/hwmon6/pwm${i}" 2>/dev/null; then
                new_pwm=$(cat "/sys/class/hwmon/hwmon6/pwm${i}" 2>/dev/null || echo "0")
                echo "    New PWM: $new_pwm"
                
                if [[ "$new_pwm" == "128" ]]; then
                    echo "    ✅ PWM$i control successful!"
                    ((pwm_writable++))
                else
                    echo "    ⚠️  PWM$i value reverted"
                fi
                
                # Restore original
                echo "$current_pwm" > "/sys/class/hwmon/hwmon6/pwm${i}" 2>/dev/null
            else
                echo "    ❌ PWM$i write failed"
            fi
        else
            echo "  PWM$i: Not writable"
        fi
    done
    
    echo ""
    echo "📊 PWM Control Summary:"
    echo "======================="
    echo "Writable PWM files: $pwm_writable/4"
    
    if [[ $pwm_writable -gt 0 ]]; then
        echo "🎉 SUCCESS: $pwm_writable fans are now controllable!"
        echo "Update your fan control scripts to include hwmon6 fans."
    else
        echo "❌ No additional fan control unlocked"
    fi
}

# Main execution
main() {
    echo "🚀 Starting hwmon6 fan unlock attempts..."
    echo ""
    
    # Check initial status
    check_hwmon6_status
    
    # Try different unlock methods
    try_create_pwm_files
    try_module_parameters
    try_ec_registers
    try_acpi_methods
    try_module_reload
    try_thermal_policy
    try_power_management
    
    # Test PWM control
    test_pwm_control
    
    echo "📋 UNLOCK SUMMARY"
    echo "================="
    echo "Attempted methods:"
    echo "1. PWM file creation"
    echo "2. Module parameter manipulation"
    echo "3. EC register access"
    echo "4. ACPI method calls"
    echo "5. Module reloading with parameters"
    echo "6. Thermal policy manipulation"
    echo "7. Power management manipulation"
    echo ""
    
    echo "🎯 RECOMMENDATIONS"
    echo "=================="
    echo "If hwmon6 fans are now controllable:"
    echo "1. Update fan_control_enhanced.sh to include hwmon6"
    echo "2. Modify GUI to show hwmon6 fans"
    echo "3. Test fan control thoroughly"
    echo "4. Document the successful method"
    echo ""
    
    echo "If no additional control was unlocked:"
    echo "1. Check BIOS settings for thermal management"
    echo "2. Try different kernel parameters"
    echo "3. Investigate EC firmware"
    echo "4. Consider hardware modifications"
    echo ""
    
    echo "🔥 hwmon6 fan unlock attempts completed!"
}

# Run main function
main "$@" 