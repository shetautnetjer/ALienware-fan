#!/bin/bash

# 🔥 Alienware Fan Discovery Script
# Comprehensive fan detection and documentation

set -e

echo "🔥 Alienware Fan Discovery"
echo "=========================="
echo "Date: $(date)"
echo "System: $(uname -a)"
echo ""

# Function to check if a file exists and is readable
file_exists() {
    [[ -r "$1" ]]
}

# Function to get fan information
get_fan_info() {
    local hwmon_path="$1"
    local fan_num="$2"
    local fan_input="$hwmon_path/fan${fan_num}_input"
    local fan_label="$hwmon_path/fan${fan_num}_label"
    local pwm_file="$hwmon_path/pwm${fan_num}"
    
    if file_exists "$fan_input"; then
        local rpm=$(cat "$fan_input" 2>/dev/null || echo "0")
        local label=""
        local pwm_status=""
        local pwm_value=""
        
        if file_exists "$fan_label"; then
            label=$(cat "$fan_label" 2>/dev/null || echo "Unknown")
        else
            label="Unlabeled"
        fi
        
        if file_exists "$pwm_file"; then
            pwm_status="✅ Controllable"
            pwm_value=$(cat "$pwm_file" 2>/dev/null || echo "0")
        else
            pwm_status="❌ Read-only"
            pwm_value="N/A"
        fi
        
        echo "  Fan $fan_num: $label"
        echo "    RPM: $rpm"
        echo "    Control: $pwm_status"
        echo "    PWM: $pwm_value"
        echo ""
    fi
}

# Function to get temperature information
get_temp_info() {
    local hwmon_path="$1"
    local temp_num="$2"
    local temp_input="$hwmon_path/temp${temp_num}_input"
    local temp_label="$hwmon_path/temp${temp_num}_label"
    
    if file_exists "$temp_input"; then
        local temp_raw=$(cat "$temp_input" 2>/dev/null || echo "0")
        local temp_celsius=$(echo "scale=1; $temp_raw / 1000" | bc 2>/dev/null || echo "0")
        local label=""
        
        if file_exists "$temp_label"; then
            label=$(cat "$temp_label" 2>/dev/null || echo "Unknown")
        else
            label="Unlabeled"
        fi
        
        echo "  Temp $temp_num: $label"
        echo "    Temperature: ${temp_celsius}°C"
        echo ""
    fi
}

# Discover all hwmon devices
echo "🔍 Discovering hwmon devices..."
echo ""

hwmon_devices=()
for hwmon_dir in /sys/class/hwmon/hwmon*; do
    if [[ -d "$hwmon_dir" ]]; then
        hwmon_name=$(basename "$hwmon_dir")
        hwmon_devices+=("$hwmon_name")
    fi
done

echo "Found ${#hwmon_devices[@]} hwmon devices:"
for device in "${hwmon_devices[@]}"; do
    echo "  $device"
done
echo ""

# Analyze each hwmon device
for hwmon_name in "${hwmon_devices[@]}"; do
    hwmon_path="/sys/class/hwmon/$hwmon_name"
    
    if [[ ! -d "$hwmon_path" ]]; then
        continue
    fi
    
    # Get device name
    device_name=""
    if file_exists "$hwmon_path/name"; then
        device_name=$(cat "$hwmon_path/name")
    else
        device_name="Unknown"
    fi
    
    echo "📊 $hwmon_name ($device_name)"
    echo "=================================="
    
    # Check for fans
    fan_count=0
    for fan_input in "$hwmon_path"/fan*_input; do
        if [[ -f "$fan_input" ]]; then
            fan_num=$(basename "$fan_input" | sed 's/fan\([0-9]*\)_input/\1/')
            get_fan_info "$hwmon_path" "$fan_num"
            ((fan_count++))
        fi
    done
    
    if [[ $fan_count -eq 0 ]]; then
        echo "  No fans detected"
        echo ""
    fi
    
    # Check for temperatures
    temp_count=0
    for temp_input in "$hwmon_path"/temp*_input; do
        if [[ -f "$temp_input" ]]; then
            temp_num=$(basename "$temp_input" | sed 's/temp\([0-9]*\)_input/\1/')
            get_temp_info "$hwmon_path" "$temp_num"
            ((temp_count++))
        fi
    done
    
    if [[ $temp_count -eq 0 ]]; then
        echo "  No temperature sensors detected"
        echo ""
    fi
    
    echo ""
done

# Summary
echo "📋 DISCOVERY SUMMARY"
echo "==================="

total_fans=0
controllable_fans=0
total_temps=0

for hwmon_name in "${hwmon_devices[@]}"; do
    hwmon_path="/sys/class/hwmon/$hwmon_name"
    
    # Count fans
    for fan_input in "$hwmon_path"/fan*_input; do
        if [[ -f "$fan_input" ]]; then
            ((total_fans++))
            fan_num=$(basename "$fan_input" | sed 's/fan\([0-9]*\)_input/\1/')
            if file_exists "$hwmon_path/pwm$fan_num"; then
                ((controllable_fans++))
            fi
        fi
    done
    
    # Count temperatures
    for temp_input in "$hwmon_path"/temp*_input; do
        if [[ -f "$temp_input" ]]; then
            ((total_temps++))
        fi
    done
done

echo "Total fans discovered: $total_fans"
echo "Controllable fans: $controllable_fans"
echo "Read-only fans: $((total_fans - controllable_fans))"
echo "Temperature sensors: $total_temps"
echo ""

# Test PWM control
echo "🧪 PWM Control Test"
echo "=================="

for hwmon_name in "${hwmon_devices[@]}"; do
    hwmon_path="/sys/class/hwmon/$hwmon_name"
    
    for pwm_file in "$hwmon_path"/pwm*; do
        if [[ -f "$pwm_file" ]]; then
            pwm_num=$(basename "$pwm_file" | sed 's/pwm\([0-9]*\)/\1/')
            echo "Testing PWM control for $hwmon_name PWM$pwm_num..."
            
            # Read current value
            current_pwm=$(cat "$pwm_file" 2>/dev/null || echo "0")
            echo "  Current PWM: $current_pwm"
            
            # Test write (if we have permission)
            if [[ -w "$pwm_file" ]]; then
                echo "  Testing PWM write..."
                echo "128" > "$pwm_file" 2>/dev/null && echo "  ✅ PWM write successful" || echo "  ❌ PWM write failed"
                
                # Read back
                new_pwm=$(cat "$pwm_file" 2>/dev/null || echo "0")
                echo "  New PWM: $new_pwm"
                
                # Restore original
                echo "$current_pwm" > "$pwm_file" 2>/dev/null
            else
                echo "  ❌ PWM file not writable"
            fi
            echo ""
        fi
    done
done

# Generate configuration
echo "⚙️  Configuration Generation"
echo "============================"

config_file="fan_config_$(date +%Y%m%d_%H%M%S).json"
echo "Generating configuration file: $config_file"

cat > "$config_file" << EOF
{
    "discovery_date": "$(date -Iseconds)",
    "system_info": {
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "distribution": "$(lsb_release -d | cut -f2 2>/dev/null || echo 'Unknown')"
    },
    "fan_summary": {
        "total_fans": $total_fans,
        "controllable_fans": $controllable_fans,
        "read_only_fans": $((total_fans - controllable_fans)),
        "temperature_sensors": $total_temps
    },
    "hwmon_devices": {
EOF

for hwmon_name in "${hwmon_devices[@]}"; do
    hwmon_path="/sys/class/hwmon/$hwmon_name"
    device_name=""
    
    if file_exists "$hwmon_path/name"; then
        device_name=$(cat "$hwmon_path/name")
    else
        device_name="Unknown"
    fi
    
    echo "        \"$hwmon_name\": {" >> "$config_file"
    echo "            \"name\": \"$device_name\"," >> "$config_file"
    echo "            \"path\": \"$hwmon_path\"," >> "$config_file"
    
    # Fans
    echo "            \"fans\": {" >> "$config_file"
    fan_count=0
    for fan_input in "$hwmon_path"/fan*_input; do
        if [[ -f "$fan_input" ]]; then
            fan_num=$(basename "$fan_input" | sed 's/fan\([0-9]*\)_input/\1/')
            label=""
            if file_exists "$hwmon_path/fan${fan_num}_label"; then
                label=$(cat "$hwmon_path/fan${fan_num}_label")
            else
                label="Fan $fan_num"
            fi
            
            controllable="false"
            if file_exists "$hwmon_path/pwm$fan_num"; then
                controllable="true"
            fi
            
            if [[ $fan_count -gt 0 ]]; then
                echo "," >> "$config_file"
            fi
            echo "                \"$fan_num\": {" >> "$config_file"
            echo "                    \"label\": \"$label\"," >> "$config_file"
            echo "                    \"controllable\": $controllable" >> "$config_file"
            echo "                }" >> "$config_file"
            ((fan_count++))
        fi
    done
    echo "            }," >> "$config_file"
    
    # Temperatures
    echo "            \"temperatures\": {" >> "$config_file"
    temp_count=0
    for temp_input in "$hwmon_path"/temp*_input; do
        if [[ -f "$temp_input" ]]; then
            temp_num=$(basename "$temp_input" | sed 's/temp\([0-9]*\)_input/\1/')
            label=""
            if file_exists "$hwmon_path/temp${temp_num}_label"; then
                label=$(cat "$hwmon_path/temp${temp_num}_label")
            else
                label="Temp $temp_num"
            fi
            
            if [[ $temp_count -gt 0 ]]; then
                echo "," >> "$config_file"
            fi
            echo "                \"$temp_num\": {" >> "$config_file"
            echo "                    \"label\": \"$label\"" >> "$config_file"
            echo "                }" >> "$config_file"
            ((temp_count++))
        fi
    done
    echo "            }" >> "$config_file"
    echo "        }" >> "$config_file"
done

echo "    }" >> "$config_file"
echo "}" >> "$config_file"

echo "✅ Configuration saved to $config_file"
echo ""

echo "🎯 RECOMMENDATIONS"
echo "=================="

if [[ $controllable_fans -gt 0 ]]; then
    echo "✅ Found $controllable_fans controllable fans - ready for fan control"
    echo "   Use the fan control scripts to manage these fans"
else
    echo "❌ No controllable fans found"
    echo "   May need to load dell-smm-hwmon module with force=1"
fi

if [[ $total_temps -gt 0 ]]; then
    echo "✅ Found $total_temps temperature sensors - monitoring available"
else
    echo "❌ No temperature sensors found"
fi

echo ""
echo "📖 Next Steps:"
echo "1. Review the generated configuration file: $config_file"
echo "2. Test fan control with: sudo ./scripts/fan_control_enhanced.sh"
echo "3. Use the GUI: sudo ./alienfan_gui.sh"
echo "4. Monitor temperatures and fan speeds"
echo ""

echo "🔥 Fan discovery completed!" 