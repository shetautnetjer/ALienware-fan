# 🔥 Alienware M18 Fan Inventory

## 📊 Discovery Summary

**Date**: June 24, 2025  
**System**: Alienware M18  
**Kernel**: 6.11.0-26-generic  
**Total Fans Discovered**: 7  
**Controllable Fans**: 3  
**Read-only Fans**: 4  

## 🎛️ Fan Details

### ✅ Controllable Fans (hwmon7 - dell_smm)

| Fan | Label | Current RPM | PWM Control | Status |
|-----|-------|-------------|-------------|---------|
| Fan 1 | Unlabeled | ~1376 RPM | PWM1 (0-255) | ✅ Active |
| Fan 2 | Unlabeled | ~1344 RPM | PWM2 (0-255) | ✅ Active |
| Fan 3 | Unlabeled | 0 RPM | PWM3 (0-255) | ⚠️ Inactive |

**Notes**: 
- These are the primary controllable fans via dell-smm-hwmon
- PWM values may revert to BIOS control after setting
- Fan 3 appears inactive but PWM control is available

### 📖 Read-only Fans (hwmon6 - dell_ddv)

| Fan | Label | Current RPM | Control | Status |
|-----|-------|-------------|---------|---------|
| Fan 1 | CPU Fan | ~1403 RPM | Read-only | ✅ Active |
| Fan 2 | Video Fan | ~1392 RPM | Read-only | ✅ Active |
| Fan 3 | Chassis Motherboard Fan | 0 RPM | Read-only | ⚠️ Inactive |
| Fan 4 | Memory Fan | ~192 RPM | Read-only | ✅ Active |

**Notes**:
- These fans are monitored but not directly controllable
- May be controlled by BIOS or other EC mechanisms
- Provides additional monitoring capabilities

## 🌡️ Temperature Sensors

### Core Temperature (hwmon10 - coretemp)
- **Core 8**: ~74°C (active)
- Additional cores available for monitoring

### NVMe Storage (hwmon2, hwmon3)
- **NVMe 1**: Temperature monitoring available
- **NVMe 2**: Temperature monitoring available

### Other Sensors
- **WiFi Module** (hwmon9): Temperature monitoring
- **Memory Controller** (hwmon8): Temperature monitoring

## 🔧 Control Methods

### Primary Control (Recommended)
```bash
# Use hwmon7 for fan control
sudo ./scripts/fan_control_enhanced.sh

# Or use GUI
sudo ./alienfan_gui.sh
```

### Direct PWM Control
```bash
# Set PWM values (0-255)
echo 128 | sudo tee /sys/class/hwmon/hwmon7/pwm1  # Fan 1
echo 128 | sudo tee /sys/class/hwmon/hwmon7/pwm2  # Fan 2
echo 128 | sudo tee /sys/class/hwmon/hwmon7/pwm3  # Fan 3
```

### Monitoring All Fans
```bash
# Monitor all fan speeds
watch -n 2 'echo "=== Controllable Fans (hwmon7) ==="; for i in {1..3}; do echo "Fan $i: $(cat /sys/class/hwmon/hwmon7/fan${i}_input) RPM"; done; echo "=== Read-only Fans (hwmon6) ==="; for i in {1..4}; do echo "Fan $i: $(cat /sys/class/hwmon/hwmon6/fan${i}_input) RPM"; done'
```

## 🎯 Fan Mapping

### Physical Layout (Inferred)
1. **CPU Fan** (hwmon6/fan1) - Primary CPU cooling
2. **GPU Fan** (hwmon6/fan2) - Graphics card cooling  
3. **VRM Fan** (hwmon7/fan1) - Voltage regulator cooling
4. **Rear Exhaust Fan** (hwmon7/fan2) - System exhaust
5. **Chassis Fan** (hwmon6/fan3) - General chassis cooling
6. **Memory Fan** (hwmon6/fan4) - Memory module cooling
7. **Additional Fan** (hwmon7/fan3) - Unknown purpose

### Control Groups
- **Group 1**: CPU + GPU fans (primary cooling)
- **Group 2**: VRM + Exhaust fans (secondary cooling)
- **Group 3**: Chassis + Memory fans (tertiary cooling)

## 📈 Performance Characteristics

### Maximum Observed Speeds
- **CPU Fan**: ~3,683 RPM
- **GPU Fan**: ~3,634 RPM  
- **VRM Fan**: ~5,150 RPM
- **Rear Exhaust**: ~3,997 RPM
- **Chassis Fan**: 0 RPM (inactive)
- **Memory Fan**: ~192 RPM (low speed)

### Temperature Thresholds
- **Normal**: < 70°C
- **Warm**: 70-80°C
- **Hot**: 80-90°C
- **Critical**: > 90°C

## 🔍 Additional Discovery

### Potential Hidden Fans
The system may have additional fans that are:
- **EC-controlled only**: Not exposed via hwmon
- **Conditional activation**: Only active under specific conditions
- **Firmware-controlled**: Managed entirely by BIOS/EC

### Investigation Methods
1. **EC Register Probing**: Direct EC port access
2. **ACPI Method Calls**: DSDT analysis
3. **Stress Testing**: Thermal load testing
4. **Firmware Analysis**: BIOS/EC firmware examination

## 🚀 Recommendations

### For Daily Use
- Use **hwmon7** for primary fan control
- Monitor **hwmon6** for additional fan status
- Set appropriate temperature thresholds
- Use auto mode for most scenarios

### For Maximum Performance
- Enable all controllable fans at high PWM
- Monitor all temperature sensors
- Use stress test mode for benchmarks
- Watch for thermal throttling

### For Quiet Operation
- Use quiet preset (PWM 64)
- Monitor temperatures carefully
- Avoid heavy workloads
- Consider undervolting

## 📝 Notes

- **Fan 3 on hwmon7** appears inactive but may activate under thermal stress
- **Chassis fan** (hwmon6/fan3) is currently inactive
- **Memory fan** runs at very low speed, likely for memory cooling
- **PWM control** may be overridden by BIOS thermal management
- **Additional fans** may exist but not be exposed via standard interfaces

## 🔄 Future Investigation

### Potential Areas
1. **EC Register Mapping**: Find additional PWM registers
2. **ACPI Methods**: Discover hidden fan control methods
3. **Firmware Reverse Engineering**: Analyze BIOS/EC firmware
4. **Thermal Zone Analysis**: Map thermal zones to fans
5. **Power Management**: Investigate power state fan behavior

### Tools Needed
- **EC Access Tools**: Direct port I/O
- **ACPI Analysis**: DSDT decompilation
- **Firmware Analysis**: BIOS/EC firmware extraction
- **Thermal Testing**: Comprehensive stress testing
- **Hardware Monitoring**: Advanced sensor monitoring

---

**Status**: ✅ **7 Fans Discovered** (3 controllable, 4 read-only)  
**Next Steps**: Test additional EC registers, investigate hidden fans  
**Priority**: Optimize control of existing 3 controllable fans 