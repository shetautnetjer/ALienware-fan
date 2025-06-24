#!/bin/bash

# 🔥 Alienware Fan Control Debug Script
# Monitors and logs fan behavior for reverse-engineering

set -e

LOG_DIR="/var/log/fan_debug"
LOG_FILE="$LOG_DIR/ec_trace.log"
DUMP_FILE="$LOG_DIR/system_dump.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Ensure log directory exists
sudo mkdir -p "$LOG_DIR"
sudo touch "$LOG_FILE"
sudo chown $USER:$USER "$LOG_FILE"

log "=== ALIENWARE FAN DEBUG SESSION STARTED ==="
log "System: $(uname -a)"
log "User: $USER"

# Phase 1: System Baseline
log "--- PHASE 1: SYSTEM BASELINE ---"

# Check kernel modules
log "Checking Dell modules..."
if lsmod | grep -q dell; then
    success "Dell modules loaded: $(lsmod | grep dell | wc -l)"
    lsmod | grep dell >> "$LOG_FILE"
else
    warning "No Dell modules detected"
fi

# Check hwmon devices
log "Scanning hwmon devices..."
for hwmon in /sys/class/hwmon/hwmon*; do
    if [ -d "$hwmon" ]; then
        name=$(cat "$hwmon/name" 2>/dev/null || echo "unknown")
        log "Found hwmon: $(basename $hwmon) - $name"
        
        # Check for PWM interfaces
        for pwm in "$hwmon"/pwm*; do
            if [ -e "$pwm" ]; then
                log "  PWM: $(basename $pwm)"
                if [ -w "$pwm" ]; then
                    success "    Writable: YES"
                else
                    warning "    Writable: NO"
                fi
            fi
        done
        
        # Check for fan inputs
        for fan in "$hwmon"/fan*_input; do
            if [ -e "$fan" ]; then
                rpm=$(cat "$fan" 2>/dev/null || echo "N/A")
                log "  Fan: $(basename $fan) = ${rpm} RPM"
            fi
        done
    fi
done

# Check sensors
log "Current sensor readings:"
sensors_output=$(sensors 2>/dev/null || echo "sensors command not available")
echo "$sensors_output" >> "$LOG_FILE"
echo "$sensors_output"

# Phase 2: EC Probe
log "--- PHASE 2: EC PROBE ---"

# Check for i8k
if [ -d "/proc/i8k" ]; then
    success "i8k proc interface found"
    ls -la /proc/i8k/ >> "$LOG_FILE"
else
    warning "i8k proc interface not found"
fi

# Try to load i8k module
log "Attempting to load i8k module..."
if sudo modprobe -v i8k force=1 2>&1; then
    success "i8k module loaded successfully"
else
    error "Failed to load i8k module"
fi

# Try dell-smm-hwmon
log "Attempting to load dell-smm-hwmon..."
if sudo modprobe -v dell-smm-hwmon force=1 2>&1; then
    success "dell-smm-hwmon module loaded successfully"
else
    error "Failed to load dell-smm-hwmon module"
fi

# Phase 3: ACPI Dump
log "--- PHASE 3: ACPI DUMP ---"

if [ -f "/sys/firmware/acpi/tables/DSDT" ]; then
    log "DSDT table found, creating backup..."
    sudo cp /sys/firmware/acpi/tables/DSDT "$LOG_DIR/dsdt_table.dat"
    success "DSDT backed up to $LOG_DIR/dsdt_table.dat"
else
    warning "DSDT table not accessible"
fi

# DMIDecode dump
log "Creating DMIDecode dump..."
sudo dmidecode > "$DUMP_FILE" 2>/dev/null || error "DMIDecode failed"
success "System dump saved to $DUMP_FILE"

# Phase 4: Kernel Messages
log "--- PHASE 4: KERNEL MESSAGES ---"
log "Recent EC-related kernel messages:"
dmesg -T | grep -i ec | tail -10 >> "$LOG_FILE"
dmesg -T | grep -i fan | tail -10 >> "$LOG_FILE"

# Phase 5: Real-time Monitoring
log "--- PHASE 5: REAL-TIME MONITORING ---"
log "Starting fan speed monitoring (Ctrl+C to stop)..."

# Function to monitor fan speeds
monitor_fans() {
    while true; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -n "[$timestamp] "
        
        # Get fan speeds
        for hwmon in /sys/class/hwmon/hwmon*; do
            if [ -d "$hwmon" ]; then
                for fan in "$hwmon"/fan*_input; do
                    if [ -e "$fan" ]; then
                        rpm=$(cat "$fan" 2>/dev/null || echo "N/A")
                        echo -n "$(basename $fan):${rpm}RPM "
                    fi
                done
            fi
        done
        echo ""
        sleep 2
    done
}

# Start monitoring
monitor_fans

log "=== DEBUG SESSION ENDED ===" 