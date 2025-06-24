#!/bin/bash

# 🌡️ Temperature-Based Fan Control for EC Fans
# Monitors system temperature and adjusts all 6 EC-controlled fans

set -e

# Configuration
TARGET_TEMP=${1:-75}  # Default target temperature: 75°C
MAX_PWM=${2:-255}     # Default max PWM: 255
MIN_PWM=64            # Minimum PWM: 25%
UPDATE_INTERVAL=5     # Update every 5 seconds

# EC fan registers
EC_FAN_REGISTERS=(
    "24:GPU Fan"
    "28:VRM Fan"
    "2C:Exhaust Fan"
    "30:Chassis Fan"
    "34:Memory Fan"
    "38:Additional Fan 1"
    "3C:Additional Fan 2"
)

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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script requires root privileges${NC}"
        echo "Run with: sudo $0 [target_temp] [max_pwm]"
        exit 1
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

# Function to set EC fan speed
set_ec_fan() {
    local register="$1"
    local pwm_value="$2"
    local fan_name="$3"
    
    # Convert decimal to hex
    local pwm_hex=$(printf "%02X" "$pwm_value")
    
    # Write to EC register
    if echo -ne "\x$pwm_hex" | dd of=/dev/port bs=1 count=1 seek=$((0x$register)) 2>/dev/null; then
        echo -e "${GREEN}✅${NC} Set $fan_name (0x$register) to PWM $pwm_value"
        return 0
    else
        echo -e "${RED}❌${NC} Failed to set $fan_name (0x$register) to PWM $pwm_value"
        return 1
    fi
}

# Function to set all EC fans
set_all_ec_fans() {
    local pwm_value="$1"
    
    for fan_info in "${EC_FAN_REGISTERS[@]}"; do
        register=$(echo "$fan_info" | cut -d: -f1)
        fan_name=$(echo "$fan_info" | cut -d: -f2)
        set_ec_fan "$register" "$pwm_value" "$fan_name"
    done
}

# Function to calculate PWM based on temperature
calculate_pwm() {
    local current_temp="$1"
    local target_temp="$2"
    local max_pwm="$3"
    
    if [[ $current_temp -le $target_temp ]]; then
        echo "$MIN_PWM"  # Minimum speed when cool
        return
    fi
    
    # Calculate PWM based on temperature difference
    local temp_diff=$((current_temp - target_temp))
    local pwm_value=$((max_pwm * temp_diff / 20))  # Scale based on 20°C range
    
    # Clamp PWM value
    if [[ $pwm_value -gt $max_pwm ]]; then
        pwm_value=$max_pwm
    fi
    if [[ $pwm_value -lt $MIN_PWM ]]; then
        pwm_value=$MIN_PWM
    fi
    
    echo "$pwm_value"
}

# Function to show status
show_status() {
    echo -e "${BLUE}🌡️  Temperature-Based Fan Control${NC}"
    echo "======================================"
    echo -e "Target Temperature: ${YELLOW}${TARGET_TEMP}°C${NC}"
    echo -e "Maximum PWM: ${YELLOW}${MAX_PWM}${NC}"
    echo -e "Update Interval: ${YELLOW}${UPDATE_INTERVAL}s${NC}"
    echo -e "EC Fans: ${GREEN}${#EC_FAN_REGISTERS[@]}${NC}"
    echo ""
    echo -e "${GREEN}Press Ctrl+C to stop${NC}"
    echo ""
}

# Function to restore BIOS control
restore_bios_control() {
    echo -e "${YELLOW}🔄 Restoring BIOS fan control...${NC}"
    set_all_ec_fans 0
    echo -e "${GREEN}✅ BIOS control restored${NC}"
}

# Main control loop
main_control_loop() {
    local iteration=0
    
    while true; do
        iteration=$((iteration + 1))
        current_temp=$(get_current_temp)
        pwm_value=$(calculate_pwm "$current_temp" "$TARGET_TEMP" "$MAX_PWM")
        
        # Clear line and show status
        echo -ne "\r"
        echo -ne "Iteration: ${BLUE}${iteration}${NC} | "
        echo -ne "Temperature: ${YELLOW}${current_temp}°C${NC} | "
        echo -ne "Target: ${YELLOW}${TARGET_TEMP}°C${NC} | "
        echo -ne "PWM: ${GREEN}${pwm_value}${NC} | "
        
        # Show temperature status
        if [[ $current_temp -le $TARGET_TEMP ]]; then
            echo -ne "Status: ${GREEN}COOL${NC}"
        elif [[ $current_temp -le $((TARGET_TEMP + 10)) ]]; then
            echo -ne "Status: ${YELLOW}WARM${NC}"
        else
            echo -ne "Status: ${RED}HOT${NC}"
        fi
        
        # Set fan speeds
        set_all_ec_fans "$pwm_value" >/dev/null
        
        sleep "$UPDATE_INTERVAL"
    done
}

# Main function
main() {
    check_root
    
    # Show configuration
    show_status
    
    # Set up signal handlers
    trap restore_bios_control EXIT
    trap 'echo -e "\n${YELLOW}🛑 Stopping temperature control...${NC}"; exit 0' INT TERM
    
    # Start control loop
    main_control_loop
}

# Run main function
main "$@" 