#!/bin/bash

# 🔥 Enhanced Alienware Fan Control Script
# Based on stress test results for maximum cooling

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
HWMON_PATH="/sys/class/hwmon/hwmon7"  # dell_smm device
LOG_FILE="/var/log/fan_debug/fan_control_enhanced.log"

# Stress test results - maximum cooling capabilities
MAX_FAN1_RPM=3766
MAX_FAN2_RPM=3710
MAX_FAN3_RPM=5093

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

info() {
    echo -e "${PURPLE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
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

# Get current temperature
get_temperature() {
    if [ -f "$HWMON_PATH/temp1_input" ]; then
        local temp=$(cat "$HWMON_PATH/temp1_input")
        echo $((temp / 1000))
    else
        echo 0
    fi
}

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
    sleep 1
}

# Set all fans to the same PWM value
set_all_fans() {
    local pwm_value=$1
    log "Setting all fans to PWM ${pwm_value}/255"
    
    for i in {1..3}; do
        set_pwm $i $pwm_value
    done
}

# Show current status with cooling efficiency
show_status() {
    echo "=== ENHANCED FAN STATUS ==="
    echo "HWMon Device: $HWMON_PATH"
    echo ""
    
    # Temperature
    local temp=$(get_temperature)
    echo "Temperature: ${temp}°C"
    
    # Fan speeds with efficiency
    echo ""
    echo "Fan Speeds (Current / Max / Efficiency):"
    local speeds=($(get_fan_speeds))
    local max_speeds=($MAX_FAN1_RPM $MAX_FAN2_RPM $MAX_FAN3_RPM)
    
    for i in {0..2}; do
        local current=${speeds[$i]}
        local max=${max_speeds[$i]}
        local efficiency=0
        if [ "$max" -gt 0 ]; then
            efficiency=$((current * 100 / max))
        fi
        echo "  Fan$((i+1)): ${current} RPM / ${max} RPM (${efficiency}%)"
    done
    
    echo ""
    echo "PWM Values:"
    for i in {1..3}; do
        if [ -f "$HWMON_PATH/pwm${i}" ]; then
            local pwm=$(cat "$HWMON_PATH/pwm${i}")
            echo "  PWM${i}: ${pwm}/255"
        else
            echo "  PWM${i}: Not available"
        fi
    done
    
    # Cooling status
    echo ""
    echo "Cooling Status:"
    if [ "$temp" -lt 60 ]; then
        echo "  🟢 COOL - System running cool"
    elif [ "$temp" -lt 80 ]; then
        echo "  🟡 WARM - Moderate cooling needed"
    elif [ "$temp" -lt 90 ]; then
        echo "  🟠 HOT - High cooling needed"
    else
        echo "  🔴 CRITICAL - Maximum cooling required"
    fi
}

# Enhanced preset modes based on stress test
set_silent_mode() {
    log "Setting SILENT mode (PWM 64/255 - 25%)"
    info "Expected RPM: ~1300-1400 (35-40% of max)"
    set_all_fans 64
}

set_normal_mode() {
    log "Setting NORMAL mode (PWM 128/255 - 50%)"
    info "Expected RPM: ~1800-2000 (50-55% of max)"
    set_all_fans 128
}

set_performance_mode() {
    log "Setting PERFORMANCE mode (PWM 192/255 - 75%)"
    info "Expected RPM: ~2800-3200 (75-85% of max)"
    set_all_fans 192
}

set_max_mode() {
    log "Setting MAX mode (PWM 255/255 - 100%)"
    info "Expected RPM: ~3700-5100 (100% of max)"
    set_all_fans 255
}

# Enhanced auto mode based on stress test results
auto_mode_enhanced() {
    log "Starting ENHANCED AUTO mode (stress-test optimized)"
    info "Based on stress test results: Max RPM - Fan1:${MAX_FAN1_RPM}, Fan2:${MAX_FAN2_RPM}, Fan3:${MAX_FAN3_RPM}"
    
    while true; do
        local temp=$(get_temperature)
        local speeds=($(get_fan_speeds))
        
        # Enhanced temperature-based control
        if [ "$temp" -lt 50 ]; then
            # Silent mode - very cool
            set_all_fans 64
            log "Temperature: ${temp}°C - SILENT mode (25% PWM)"
        elif [ "$temp" -lt 65 ]; then
            # Normal mode - cool
            set_all_fans 128
            log "Temperature: ${temp}°C - NORMAL mode (50% PWM)"
        elif [ "$temp" -lt 80 ]; then
            # Performance mode - warm
            set_all_fans 192
            log "Temperature: ${temp}°C - PERFORMANCE mode (75% PWM)"
        elif [ "$temp" -lt 90 ]; then
            # High performance mode - hot
            set_all_fans 230
            log "Temperature: ${temp}°C - HIGH PERFORMANCE mode (90% PWM)"
        else
            # Maximum mode - critical
            set_all_fans 255
            log "Temperature: ${temp}°C - MAXIMUM mode (100% PWM) - CRITICAL!"
        fi
        
        # Show current efficiency
        local avg_rpm=$(( (speeds[0] + speeds[1] + speeds[2]) / 3 ))
        local max_avg=$(( (MAX_FAN1_RPM + MAX_FAN2_RPM + MAX_FAN3_RPM) / 3 ))
        local efficiency=$((avg_rpm * 100 / max_avg))
        
        info "Current RPM: ${speeds[0]}, ${speeds[1]}, ${speeds[2]} (${efficiency}% of max cooling)"
        
        sleep 10
    done
}

# Gaming mode - optimized for gaming sessions
gaming_mode() {
    log "Starting GAMING mode (optimized for gaming)"
    info "Gaming mode: Balanced performance and noise"
    
    while true; do
        local temp=$(get_temperature)
        
        # Gaming-optimized control
        if [ "$temp" -lt 60 ]; then
            set_all_fans 128  # Normal for cool gaming
        elif [ "$temp" -lt 75 ]; then
            set_all_fans 192  # Performance for warm gaming
        elif [ "$temp" -lt 85 ]; then
            set_all_fans 230  # High performance for hot gaming
        else
            set_all_fans 255  # Max for critical gaming
        fi
        
        log "Gaming mode - Temperature: ${temp}°C, PWM: $(cat "$HWMON_PATH/pwm1")/255"
        sleep 15
    done
}

# Stress test mode - maximum cooling
stress_mode() {
    log "Starting STRESS TEST mode (maximum cooling)"
    info "Stress mode: Maximum cooling for heavy workloads"
    
    # Set to maximum immediately
    set_all_fans 255
    
    while true; do
        local temp=$(get_temperature)
        local speeds=($(get_fan_speeds))
        
        # Always maintain maximum cooling in stress mode
        set_all_fans 255
        
        local avg_rpm=$(( (speeds[0] + speeds[1] + speeds[2]) / 3 ))
        log "STRESS MODE - Temperature: ${temp}°C, Avg RPM: ${avg_rpm}, PWM: 255/255"
        
        # Exit stress mode if temperature drops significantly
        if [ "$temp" -lt 70 ]; then
            log "Temperature dropped to ${temp}°C, exiting stress mode"
            break
        fi
        
        sleep 5
    done
}

# Help function
show_help() {
    echo "🔥 Enhanced Alienware Fan Control Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status                    Show enhanced fan status with efficiency"
    echo "  silent                    Set silent mode (25% PWM)"
    echo "  normal                    Set normal mode (50% PWM)"
    echo "  performance               Set performance mode (75% PWM)"
    echo "  max                       Set maximum mode (100% PWM)"
    echo "  auto                      Start enhanced auto mode (stress-test optimized)"
    echo "  gaming                    Start gaming mode (gaming optimized)"
    echo "  stress                    Start stress mode (maximum cooling)"
    echo "  set <fan> <pwm>          Set specific fan PWM (0-255)"
    echo "  set-all <pwm>            Set all fans PWM (0-255)"
    echo "  help                      Show this help"
    echo ""
    echo "Enhanced Features:"
    echo "  - Based on stress test results (max RPM: ${MAX_FAN1_RPM}, ${MAX_FAN2_RPM}, ${MAX_FAN3_RPM})"
    echo "  - Efficiency calculations"
    echo "  - Gaming-optimized mode"
    echo "  - Stress test mode for maximum cooling"
    echo ""
    echo "Examples:"
    echo "  $0 status                 # Show enhanced status"
    echo "  $0 auto                   # Start enhanced auto mode"
    echo "  $0 gaming                 # Start gaming mode"
    echo "  $0 stress                 # Start stress mode"
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
        auto_mode_enhanced
        ;;
    "gaming")
        gaming_mode
        ;;
    "stress")
        stress_mode
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