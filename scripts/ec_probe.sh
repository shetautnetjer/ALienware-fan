#!/bin/bash

# 🔥 EC (Embedded Controller) Probe Script
# Attempts various methods to interact with Dell's EC

set -e

LOG_DIR="/var/log/fan_debug"
LOG_FILE="$LOG_DIR/ec_probe.log"
DUMP_DIR="$LOG_DIR/ec_dumps"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Setup
sudo mkdir -p "$LOG_DIR" "$DUMP_DIR"
sudo touch "$LOG_FILE"
sudo chown $USER:$USER "$LOG_FILE"

log "=== EC PROBE SESSION STARTED ==="
log "System: $(uname -a)"

# Method 1: Direct EC Port Access
log "--- METHOD 1: DIRECT EC PORT ACCESS ---"

# Check if we can access EC ports
if [ -w "/dev/port" ]; then
    success "Direct port access available"
    
    # Common EC ports for Dell systems
    EC_PORTS=(0x62 0x66 0x80 0x84 0x88 0x8C)
    
    for port in "${EC_PORTS[@]}"; do
        log "Probing EC port 0x${port#0x}..."
        if sudo dd if=/dev/port bs=1 count=1 skip=$((0x${port#0x})) 2>/dev/null | hexdump -C; then
            success "Port 0x${port#0x} accessible"
        else
            warning "Port 0x${port#0x} not accessible"
        fi
    done
else
    warning "Direct port access not available"
fi

# Method 2: SMM (System Management Mode) Access
log "--- METHOD 2: SMM ACCESS ---"

# Try dell-smm-hwmon with different parameters
SMM_PARAMS=("force=1" "ignore_dmi=1" "restricted=0" "fan_mult=1" "fan_div=1")

for param in "${SMM_PARAMS[@]}"; do
    log "Testing dell-smm-hwmon with $param..."
    if sudo modprobe -r dell-smm-hwmon 2>/dev/null; then
        log "Unloaded dell-smm-hwmon"
    fi
    
    if sudo modprobe dell-smm-hwmon $param 2>&1; then
        success "dell-smm-hwmon loaded with $param"
        
        # Check if it created any interfaces
        for hwmon in /sys/class/hwmon/hwmon*; do
            if [ -d "$hwmon" ]; then
                name=$(cat "$hwmon/name" 2>/dev/null || echo "unknown")
                if [[ "$name" == *"dell"* ]]; then
                    success "Found Dell hwmon: $(basename $hwmon)"
                    ls -la "$hwmon"/ >> "$LOG_FILE"
                fi
            fi
        done
    else
        warning "Failed to load dell-smm-hwmon with $param"
    fi
done

# Method 3: i8k Module Testing
log "--- METHOD 3: i8k MODULE TESTING ---"

I8K_PARAMS=("force=1" "ignore_dmi=1" "fan_mult=1" "fan_div=1" "power_status=1")

for param in "${I8K_PARAMS[@]}"; do
    log "Testing i8k with $param..."
    if sudo modprobe -r i8k 2>/dev/null; then
        log "Unloaded i8k"
    fi
    
    if sudo modprobe i8k $param 2>&1; then
        success "i8k loaded with $param"
        
        # Test i8kctl if available
        if command -v i8kctl >/dev/null 2>&1; then
            log "Testing i8kctl commands..."
            i8kctl fan >> "$LOG_FILE" 2>&1 || warning "i8kctl fan failed"
            i8kctl temp >> "$LOG_FILE" 2>&1 || warning "i8kctl temp failed"
        fi
    else
        warning "Failed to load i8k with $param"
    fi
done

# Method 4: ACPI Method Calls
log "--- METHOD 4: ACPI METHOD CALLS ---"

# Common ACPI methods for fan control
ACPI_METHODS=("_SB.PCI0.LPCB.EC.FAN" "_SB.PCI0.LPCB.EC.FAN1" "_SB.PCI0.LPCB.EC.FAN2" 
              "_SB.PCI0.LPCB.EC.SFAN" "_SB.PCI0.LPCB.EC.CFAN" "_SB.PCI0.LPCB.EC.PFAN")

for method in "${ACPI_METHODS[@]}"; do
    log "Testing ACPI method: $method"
    if echo "$method" | sudo tee /proc/acpi/call >/dev/null 2>&1; then
        result=$(sudo cat /proc/acpi/call 2>/dev/null || echo "N/A")
        success "ACPI method $method returned: $result"
    else
        warning "ACPI method $method not available"
    fi
done

# Method 5: DSDT Analysis
log "--- METHOD 5: DSDT ANALYSIS ---"

if [ -f "/sys/firmware/acpi/tables/DSDT" ]; then
    log "Extracting DSDT table..."
    sudo cp /sys/firmware/acpi/tables/DSDT "$DUMP_DIR/dsdt_table.dat"
    success "DSDT saved to $DUMP_DIR/dsdt_table.dat"
    
    # Try to decompile if iasl is available
    if command -v iasl >/dev/null 2>&1; then
        log "Decompiling DSDT..."
        if iasl -d "$DUMP_DIR/dsdt_table.dat" 2>/dev/null; then
            success "DSDT decompiled successfully"
            
            # Search for fan-related methods
            log "Searching for fan methods in DSDT..."
            if [ -f "$DUMP_DIR/dsdt_table.dsl" ]; then
                grep -i "fan\|thermal\|cooling" "$DUMP_DIR/dsdt_table.dsl" | head -20 >> "$LOG_FILE"
                success "Fan methods found in DSDT (see log for details)"
            fi
        else
            warning "DSDT decompilation failed"
        fi
    else
        warning "iasl not available for DSDT decompilation"
    fi
else
    warning "DSDT table not accessible"
fi

# Method 6: Firmware Interface Testing
log "--- METHOD 6: FIRMWARE INTERFACE TESTING ---"

# Test various firmware interfaces
FW_INTERFACES=("/sys/firmware/dmi/tables/smbios_entry_point" 
               "/sys/firmware/efi/efivars" 
               "/sys/class/dmi/id")

for interface in "${FW_INTERFACES[@]}"; do
    if [ -e "$interface" ]; then
        success "Firmware interface found: $interface"
        ls -la "$interface" >> "$LOG_FILE"
    else
        warning "Firmware interface not found: $interface"
    fi
done

# Method 7: Kernel Module Hacking
log "--- METHOD 7: KERNEL MODULE HACKING ---"

# Check if we can modify module parameters at runtime
if [ -d "/sys/module/dell_smm_hwmon" ]; then
    success "dell_smm_hwmon module loaded"
    
    # List available parameters
    if [ -d "/sys/module/dell_smm_hwmon/parameters" ]; then
        log "Available dell_smm_hwmon parameters:"
        ls /sys/module/dell_smm_hwmon/parameters/ >> "$LOG_FILE"
        
        # Try to modify parameters
        for param in /sys/module/dell_smm_hwmon/parameters/*; do
            if [ -f "$param" ]; then
                param_name=$(basename "$param")
                current_value=$(cat "$param" 2>/dev/null || echo "N/A")
                log "Parameter $param_name = $current_value"
            fi
        done
    fi
fi

# Method 8: Stress Testing
log "--- METHOD 8: STRESS TESTING ---"

log "Running stress test to trigger thermal management..."
if command -v stress-ng >/dev/null 2>&1; then
    log "Starting stress-ng for 30 seconds..."
    timeout 30s stress-ng --cpu 4 --io 2 --vm 1 --vm-bytes 1G >/dev/null 2>&1 &
    STRESS_PID=$!
    
    # Monitor fan speeds during stress
    for i in {1..15}; do
        sleep 2
        log "Stress test iteration $i/15"
        for hwmon in /sys/class/hwmon/hwmon*; do
            if [ -d "$hwmon" ]; then
                for fan in "$hwmon"/fan*_input; do
                    if [ -e "$fan" ]; then
                        rpm=$(cat "$fan" 2>/dev/null || echo "N/A")
                        log "  $(basename $fan): ${rpm} RPM"
                    fi
                done
            fi
        done
    done
    
    # Clean up stress test
    kill $STRESS_PID 2>/dev/null || true
    success "Stress test completed"
else
    warning "stress-ng not available for testing"
fi

# Final Summary
log "--- PROBE SUMMARY ---"
log "Generated files:"
ls -la "$DUMP_DIR"/ >> "$LOG_FILE"

log "Current hwmon devices:"
ls -la /sys/class/hwmon/ >> "$LOG_FILE"

log "Loaded Dell modules:"
lsmod | grep dell >> "$LOG_FILE"

log "=== EC PROBE SESSION COMPLETED ==="
log "Check $LOG_FILE for detailed results"
log "Check $DUMP_DIR for extracted data" 