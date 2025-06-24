# 🤝 Contributing to Alienware Linux Fan Control

**Every test matters!** We're building a shared knowledgebase to unlock fan control on Alienware systems. Your contributions help hundreds of Linux users.

## 📋 Debug Rule - REQUIRED

**📌 Every time you test a fan control attempt, you MUST log the following:**

### Required Information
- **Timestamp** (`date`)
- **System Info** (`uname -a`)
- **Module Version** (`lsmod | grep dell`)
- **Sensors Output** (`sensors`)
- **PWM Path Attempted** (`/sys/class/hwmon/hwmonX/pwmY`)
- **Whether RPM Changed** (before/after comparison)
- **BIOS Thermal Mode** at boot
- **Kernel Logs** (`dmesg -T | grep fan`)

### Logging Template
```bash
# Copy this template for each test
echo "=== FAN CONTROL TEST $(date) ===" >> /var/log/fan_debug/ec_trace.log
echo "System: $(uname -a)" >> /var/log/fan_debug/ec_trace.log
echo "Modules: $(lsmod | grep dell)" >> /var/log/fan_debug/ec_trace.log
echo "Sensors: $(sensors | grep -i fan)" >> /var/log/fan_debug/ec_trace.log
echo "PWM Path: /sys/class/hwmon/hwmonX/pwmY" >> /var/log/fan_debug/ec_trace.log
echo "RPM Before: XXX" >> /var/log/fan_debug/ec_trace.log
echo "RPM After: XXX" >> /var/log/fan_debug/ec_trace.log
echo "Kernel Logs: $(dmesg -T | grep fan | tail -5)" >> /var/log/fan_debug/ec_trace.log
echo "=== TEST END ===" >> /var/log/fan_debug/ec_trace.log
```

## 🎯 How to Contribute

### 1. System Information
**Always include your system details:**
- **Model**: Alienware M18/M17/M15/etc.
- **Kernel Version**: `uname -r`
- **BIOS Version**: `sudo dmidecode -s bios-version`
- **Distribution**: Ubuntu/Arch/Fedora/etc.

### 2. Testing Methods

#### Method A: PWM Interface Testing
```bash
# Find PWM interfaces
ls /sys/class/hwmon/hwmon*/pwm*

# Test write access
echo 255 | sudo tee /sys/class/hwmon/hwmonX/pwmY

# Check if enable exists
ls /sys/class/hwmon/hwmonX/pwmY_enable
```

#### Method B: i8k Module Testing
```bash
# Load i8k module
sudo modprobe i8k force=1

# Test i8kctl
i8kctl fan
i8kctl temp
```

#### Method C: dell-smm-hwmon Testing
```bash
# Load with different parameters
sudo modprobe dell-smm-hwmon force=1
sudo modprobe dell-smm-hwmon ignore_dmi=1
```

#### Method D: ACPI Method Testing
```bash
# Test ACPI methods
echo "_SB.PCI0.LPCB.EC.FAN" | sudo tee /proc/acpi/call
sudo cat /proc/acpi/call
```

### 3. Reporting Results

#### GitHub Issues
Create issues with this format:

**Title**: `[M18] PWM write test - BLOCKED/SUCCESS`

**Body**:
```markdown
## System Info
- Model: Alienware M18
- Kernel: 6.11.0-26-generic
- BIOS: 1.0.0
- Distro: Ubuntu 23.10

## Test Method
- Method: PWM Interface Testing
- Path: /sys/class/hwmon/hwmon0/pwm1
- Command: `echo 255 | sudo tee /sys/class/hwmon/hwmon0/pwm1`

## Results
- Status: ❌ BLOCKED
- RPM Before: 1320
- RPM After: 1320 (no change)
- Error: Permission denied

## Logs
[Attach relevant log files]

## Additional Notes
- BIOS thermal mode: Performance
- Any other observations
```

### 4. Tagging System

Use these tags in issues:
- `[M18]` - Alienware M18 specific
- `[M17]` - Alienware M17 specific  
- `[M15]` - Alienware M15 specific
- `[PWM]` - PWM interface testing
- `[i8k]` - i8k module testing
- `[ACPI]` - ACPI method testing
- `[SMM]` - SMM access testing
- `[BLOCKED]` - Method blocked by EC
- `[SUCCESS]` - Method worked
- `[PARTIAL]` - Partial success

## 🔬 Advanced Testing

### Stress Testing
```bash
# Install stress-ng
sudo apt install stress-ng

# Run stress test while monitoring fans
./scripts/fanwatch.sh &
stress-ng --cpu 4 --io 2 --vm 1 --vm-bytes 1G
```

### ACPI Dump Analysis
```bash
# Extract DSDT
sudo cat /sys/firmware/acpi/tables/DSDT > dsdt_table.dat

# Decompile (requires iasl)
iasl -d dsdt_table.dat

# Search for fan methods
grep -i fan dsdt_table.dsl
```

### Firmware Dumps
```bash
# DMIDecode dump
sudo dmidecode > system_dump.txt

# Kernel EC messages
sudo dmesg | grep -i ec > ec_messages.txt
```

## 📊 Status Tracking

### Confirmed Working Methods
- [ ] Document any working methods here

### Confirmed Blocked Methods  
- [ ] Document blocked methods here

### Needs Testing
- [ ] PWM interface write access
- [ ] i8k module with force=1
- [ ] dell-smm-hwmon with ignore_dmi=1
- [ ] ACPI method calls
- [ ] Direct EC port access

## 🚀 Code Contributions

### Script Development
When writing scripts:
1. Use the logging functions from `scripts/fanwatch.sh`
2. Include error handling
3. Add color-coded output
4. Document all assumptions

### Example Script Structure
```bash
#!/bin/bash
# Script description

set -e

# Include logging functions
source "$(dirname "$0")/../scripts/logging.sh"

log "Starting test..."
# Your code here
success "Test completed"
```

## 🤝 Community Guidelines

1. **Be Respectful**: Everyone is learning together
2. **Share Everything**: Even failed attempts help
3. **Document Thoroughly**: Assume someone else will follow your steps
4. **Test Safely**: Don't risk hardware damage
5. **Help Others**: Answer questions and share knowledge

## 📞 Getting Help

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Wiki**: For documentation and guides

---

**🔥 Remember: Every test, every log, every failure brings us closer to unlocking fan control!** 