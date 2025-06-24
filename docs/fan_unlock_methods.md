# 🔥 Alienware Fan Unlock Methods

## 🎯 Overview

This document outlines various methods to unlock additional fan control on Alienware laptops, bypassing BIOS restrictions to gain manual control over fans that are normally read-only.

## 📊 Current Status

### ✅ Controllable Fans (hwmon7 - dell_smm)
- **Fan 1**: PWM1 controllable (0-255)
- **Fan 2**: PWM2 controllable (0-255)  
- **Fan 3**: PWM3 controllable (0-255)

### 📖 Read-only Fans (hwmon6 - dell_ddv)
- **CPU Fan**: ~1300 RPM (read-only)
- **Video Fan**: ~1340 RPM (read-only)
- **Chassis Motherboard Fan**: ~4120 RPM (read-only)
- **Memory Fan**: ~1360 RPM (read-only)

## 🔧 Unlock Methods

### Method 1: Kernel Module Parameters

#### dell-smm-hwmon Parameters
```bash
# Unload current module
sudo modprobe -r dell-smm-hwmon

# Try different parameter combinations
sudo modprobe dell-smm-hwmon force=1
sudo modprobe dell-smm-hwmon force=1 ignore_dmi=1
sudo modprobe dell-smm-hwmon force=1 ignore_dmi=1 restricted=0
sudo modprobe dell-smm-hwmon force=1 ignore_dmi=1 restricted=0 fan_mult=1
sudo modprobe dell-smm-hwmon force=1 ignore_dmi=1 restricted=0 fan_div=1
sudo modprobe dell-smm-hwmon force=1 ignore_dmi=1 restricted=0 power_status=1
```

#### Runtime Parameter Modification
```bash
# Modify parameters while module is loaded
echo "1" | sudo tee /sys/module/dell_smm_hwmon/parameters/force
echo "1" | sudo tee /sys/module/dell_smm_hwmon/parameters/ignore_dmi
echo "0" | sudo tee /sys/module/dell_smm_hwmon/parameters/restricted
```

### Method 2: Direct EC Access

#### EC Port Access
```bash
# Check if /dev/port is accessible
ls -la /dev/port

# Read EC registers directly
sudo dd if=/dev/port bs=1 count=1 skip=0x62
sudo dd if=/dev/port bs=1 count=1 skip=0x66
```

#### Python EC Control Script
```bash
# Run the EC fan control script
sudo python3 scripts/ec_fan_control.py
```

**Features**:
- Direct EC register access
- Fan speed reading and control
- Interactive command interface
- EC register scanning

### Method 3: ACPI Method Calls

#### Install acpi_call
```bash
# Ubuntu/Debian
sudo apt install acpi-call-dkms

# Or compile from source
git clone https://github.com/mkottman/acpi_call.git
cd acpi_call
make
sudo insmod acpi_call.ko
```

#### Test ACPI Methods
```bash
# Common fan control methods
acpi_call -p "_SB.PCI0.LPCB.EC.FAN1"
acpi_call -p "_SB.PCI0.LPCB.EC.FAN2"
acpi_call -p "_SB.PCI0.LPCB.EC.FAN3"
acpi_call -p "_SB.PCI0.LPCB.EC.FAN4"
acpi_call -p "_SB.PCI0.LPCB.EC.SFAN"
acpi_call -p "_SB.PCI0.LPCB.EC.CFAN"
acpi_call -p "_SB.PCI0.LPCB.EC.PFAN"
acpi_call -p "_SB.PCI0.LPCB.EC.FAN_CTL"
```

### Method 4: Thermal Policy Manipulation

#### Thermal Zone Control
```bash
# List thermal zones
ls /sys/class/thermal/

# Check thermal policies
cat /sys/class/thermal/thermal_zone*/policy

# Set performance policy
echo "performance" | sudo tee /sys/class/thermal/thermal_zone*/policy

# Check cooling devices
ls /sys/class/thermal/thermal_zone*/cdev*
```

#### Cooling Device Control
```bash
# Check cooling device states
cat /sys/class/thermal/thermal_zone*/cdev*/cur_state

# Set cooling device state
echo "1" | sudo tee /sys/class/thermal/thermal_zone*/cdev*/cur_state
```

### Method 5: Power Management

#### CPU Frequency Scaling
```bash
# Set performance governor
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Check available governors
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
```

#### Power Supply Control
```bash
# Check power supplies
ls /sys/class/power_supply/

# Check charge control
cat /sys/class/power_supply/*/charge_control_start_threshold
```

### Method 6: BIOS Settings

#### Recommended BIOS Changes
1. **Thermal Management**: Disable or set to "Performance"
2. **Fan Control**: Set to "Manual" if available
3. **Power Management**: Set to "Performance"
4. **Thermal Throttling**: Disable if possible

#### BIOS Access
```bash
# Check current BIOS settings
sudo dmidecode -t 39

# Check thermal management
sudo dmidecode -t 4
```

## 🛠️ Automated Unlock Scripts

### General Fan Unlock
```bash
# Run comprehensive unlock script
sudo ./scripts/unlock_fans.sh
```

**Features**:
- Tests all unlock methods
- Module parameter variations
- EC port access
- ACPI method calls
- Thermal policy manipulation

### hwmon6 Specific Unlock
```bash
# Target hwmon6 fans specifically
sudo ./scripts/unlock_hwmon6_fans.sh
```

**Features**:
- Focused on CPU, Video, Chassis, Memory fans
- PWM file creation attempts
- Module parameter manipulation
- EC register access
- Success testing

## 🔍 Investigation Tools

### EC Probe Script
```bash
# Comprehensive EC investigation
sudo ./scripts/ec_probe.sh
```

### Fan Discovery Script
```bash
# Discover all fans and capabilities
./scripts/fan_discovery.sh
```

### Real-time Monitoring
```bash
# Monitor all fan speeds
watch -n 2 'echo "=== hwmon6 ==="; for i in {1..4}; do echo "Fan $i: $(cat /sys/class/hwmon/hwmon6/fan${i}_input) RPM"; done; echo "=== hwmon7 ==="; for i in {1..3}; do echo "Fan $i: $(cat /sys/class/hwmon/hwmon7/fan${i}_input 2>/dev/null || echo "N/A") RPM"; done'
```

## 🎯 Success Indicators

### PWM File Creation
- **Success**: PWM files appear in `/sys/class/hwmon/hwmon6/`
- **Test**: `ls /sys/class/hwmon/hwmon6/pwm*`

### Fan Speed Changes
- **Success**: Fan speeds respond to PWM changes
- **Test**: Monitor RPM while changing PWM values

### EC Access
- **Success**: Can read/write EC registers
- **Test**: EC control script works

### ACPI Methods
- **Success**: ACPI methods return values
- **Test**: `acpi_call` commands succeed

## ⚠️ Safety Considerations

### Temperature Monitoring
- **Always monitor temperatures** when testing fan control
- **Don't disable fans completely** for extended periods
- **Watch for thermal throttling** indicators

### Hardware Protection
- **Test gradually** - start with low PWM values
- **Monitor fan behavior** - ensure fans respond correctly
- **Have fallback plan** - know how to restore BIOS control

### System Stability
- **Test on non-critical workloads** first
- **Monitor system stability** during testing
- **Keep BIOS backup** if making firmware changes

## 🔄 Troubleshooting

### Common Issues

#### Module Won't Load
```bash
# Check module dependencies
modinfo dell-smm-hwmon

# Check kernel messages
dmesg | grep dell

# Try different kernel versions
uname -r
```

#### EC Access Denied
```bash
# Check /dev/port permissions
ls -la /dev/port

# Check if running as root
whoami

# Check iopl restrictions
cat /proc/sys/kernel/yama/ptrace_scope
```

#### ACPI Methods Fail
```bash
# Check if acpi_call is loaded
lsmod | grep acpi_call

# Check ACPI tables
ls /sys/firmware/acpi/tables/

# Check kernel messages
dmesg | grep acpi
```

### Recovery Procedures

#### Restore BIOS Control
```bash
# Unload custom modules
sudo modprobe -r dell-smm-hwmon
sudo modprobe -r acpi_call

# Reload default modules
sudo modprobe dell-smm-hwmon

# Reset thermal policies
echo "step_wise" | sudo tee /sys/class/thermal/thermal_zone*/policy
```

#### Emergency Fan Control
```bash
# Force maximum fan speed via EC
sudo python3 scripts/ec_fan_control.py
# Then: set fan1 255, set fan2 255, etc.

# Or use direct PWM control
echo "255" | sudo tee /sys/class/hwmon/hwmon7/pwm*
```

## 📈 Future Research

### Advanced Methods
1. **EC Firmware Analysis**: Reverse engineer EC firmware
2. **Hardware Modifications**: Physical fan control circuits
3. **Custom Kernel Modules**: Write specialized fan control modules
4. **Firmware Patching**: Modify BIOS/EC firmware directly

### Investigation Areas
1. **Additional EC Registers**: Find hidden fan control registers
2. **ACPI DSDT Analysis**: Discover new ACPI methods
3. **Thermal Zone Mapping**: Map thermal zones to specific fans
4. **Power State Behavior**: Investigate fan behavior in different power states

---

**Status**: 🔄 **In Progress** - Multiple methods being tested  
**Priority**: Unlock hwmon6 fans (CPU, Video, Chassis, Memory)  
**Next Steps**: Test EC direct access, investigate additional registers 