#!/bin/bash

# 🔥 Alienware Fan Control Script
# Based on discoveries from ec_probe.sh and ec_poke_watch.py

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HWMON_PATH="/sys/class/hwmon/hwmon7"  # dell_smm device
LOG_FILE="/var/log/fan_debug/fan_control.log"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
    exit 1
fi

# Check if hwmon device exists
if [ ! -d "$HWMON_PATH" ]; then
    error "HWMon device not found: $HWMON_PATH"
    error "Try loading dell-smm-hwmon module: sudo modprobe dell-smm-hwmon force=1"
    exit 1
fi

# Get current fan speeds
get_fan_speeds() {
    local speeds=()
    for i in {1..3}; do
        if [ -f "$HWMON_PATH/fan${i}_input" ]; then
            speeds+=($(cat "$HWMON_PATH/fan${i}_input"))
        else
            speeds+=(0)
        fi
    done
    echo "${speeds[@]}"
}

# Get current PWM values
get_pwm_values() {
    local pwm_values=()
    for i in {1..3}; do
        if [ -f "$HWMON_PATH/pwm${i}" ]; then
            pwm_values+=($(cat "$HWMON_PATH/pwm${i}"))
        else
            pwm_values+=(0)
        fi
    done
    echo "${pwm_values[@]}"
}

# Set PWM value for a specific fan
set_pwm() {
    local fan_num=$1
    local pwm_value=$2
    
    if [ ! -f "$HWMON_PATH/pwm${fan_num}" ]; then
        error "PWM${fan_num} not available"
        return 1
    fi
    
    if [ "$pwm_value" -lt 0 ] || [ "$pwm_value" -gt 255 ]; then
        error "PWM value must be between 0 and 255"
        return 1
    fi
    
    log "Setting PWM${fan_num} to ${pwm_value}/255"
    echo "$pwm_value" > "$HWMON_PATH/pwm${fan_num}"
    
    # Wait for fan response
    sleep 2
    
    # Check new fan speed
    if [ -f "$HWMON_PATH/fan${fan_num}_input" ]; then
        local new_speed=$(cat "$HWMON_PATH/fan${fan_num}_input")
        log "Fan${fan_num} speed: ${new_speed} RPM"
    fi
}

# Set all fans to the same PWM value
set_all_fans() {
    local pwm_value=$1
    log "Setting all fans to PWM ${pwm_value}/255"
    
    for i in {1..3}; do
        set_pwm $i $pwm_value
    done
}

# Show current status
show_status() {
    echo "=== FAN STATUS ==="
    echo "HWMon Device: $HWMON_PATH"
    echo ""
    
    # Fan speeds
    echo "Fan Speeds:"
    for i in {1..3}; do
        if [ -f "$HWMON_PATH/fan${i}_input" ]; then
            local speed=$(cat "$HWMON_PATH/fan${i}_input")
            echo "  Fan${i}: ${speed} RPM"
        else
            echo "  Fan${i}: Not available"
        fi
    done
    echo ""
    
    # PWM values
    echo "PWM Values:"
    for i in {1..3}; do
        if [ -f "$HWMON_PATH/pwm${i}" ]; then
            local pwm=$(cat "$HWMON_PATH/pwm${i}")
            echo "  PWM${i}: ${pwm}/255"
        else
            echo "  PWM${i}: Not available"
        fi
    done
    echo ""
    
    # Temperature (if available)
    if [ -f "$HWMON_PATH/temp1_input" ]; then
        local temp=$(cat "$HWMON_PATH/temp1_input")
        temp=$((temp / 1000))
        echo "Temperature: ${temp}°C"
    fi
}

# Preset modes
set_silent_mode() {
    log "Setting SILENT mode (PWM 64/255 - 25%)"
    set_all_fans 64
}

set_normal_mode() {
    log "Setting NORMAL mode (PWM 128/255 - 50%)"
    set_all_fans 128
}

set_performance_mode() {
    log "Setting PERFORMANCE mode (PWM 192/255 - 75%)"
    set_all_fans 192
}

set_max_mode() {
    log "Setting MAX mode (PWM 255/255 - 100%)"
    set_all_fans 255
}

# Auto mode based on temperature
auto_mode() {
    log "Starting AUTO mode (temperature-based control)"
    
    while true; do
        if [ -f "$HWMON_PATH/temp1_input" ]; then
            local temp=$(cat "$HWMON_PATH/temp1_input")
            temp=$((temp / 1000))
            
            # Temperature-based PWM control
            if [ "$temp" -lt 50 ]; then
                set_all_fans 64   # Silent
            elif [ "$temp" -lt 70 ]; then
                set_all_fans 128  # Normal
            elif [ "$temp" -lt 85 ]; then
                set_all_fans 192  # Performance
            else
                set_all_fans 255  # Max
            fi
            
            log "Temperature: ${temp}°C, PWM: $(cat "$HWMON_PATH/pwm1")/255"
        else
            warning "Temperature sensor not available, using normal mode"
            set_all_fans 128
        fi
        
        sleep 10
    done
}

# Help function
show_help() {
    echo "🔥 Alienware Fan Control Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status                    Show current fan status"
    echo "  silent                    Set silent mode (25% PWM)"
    echo "  normal                    Set normal mode (50% PWM)"
    echo "  performance               Set performance mode (75% PWM)"
    echo "  max                       Set maximum mode (100% PWM)"
    echo "  auto                      Start auto mode (temperature-based)"
    echo "  set <fan> <pwm>          Set specific fan PWM (0-255)"
    echo "  set-all <pwm>            Set all fans PWM (0-255)"
    echo "  help                      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 status                 # Show current status"
    echo "  $0 silent                 # Set silent mode"
    echo "  $0 set 1 128              # Set fan1 to 50%"
    echo "  $0 set-all 255            # Set all fans to 100%"
    echo "  $0 auto                   # Start auto mode"
    echo ""
    echo "Note: This script must be run as root"
}

# Main script logic
case "${1:-help}" in
    "status")
        show_status
        ;;
    "silent")
        set_silent_mode
        show_status
        ;;
    "normal")
        set_normal_mode
        show_status
        ;;
    "performance")
        set_performance_mode
        show_status
        ;;
    "max")
        set_max_mode
        show_status
        ;;
    "auto")
        auto_mode
        ;;
    "set")
        if [ -z "$2" ] || [ -z "$3" ]; then
            error "Usage: $0 set <fan_number> <pwm_value>"
            exit 1
        fi
        set_pwm "$2" "$3"
        show_status
        ;;
    "set-all")
        if [ -z "$2" ]; then
            error "Usage: $0 set-all <pwm_value>"
            exit 1
        fi
        set_all_fans "$2"
        show_status
        ;;
    "help"|*)
        show_help
        ;;
esac 