# 🔍 Research Findings & Discoveries

**Documenting our reverse-engineering journey to unlock Alienware fan control.**

## 📊 Current Understanding

### What We Know Works
- ✅ **Fan Speed Reading**: `fan1_input` provides accurate RPM readings
- ✅ **EC Auto-Ramp**: Embedded controller responds to thermal load
- ✅ **BIOS Override**: Full speed mode works when enabled in BIOS
- ✅ **Stress Detection**: `stress-ng` successfully triggers fan ramping

### What We Know is Blocked
- ❌ **Direct PWM Write**: `/sys/class/hwmon/hwmon*/pwm*` exists but not writable
- ❌ **PWM Enable**: `pwm*_enable` files are missing entirely
- ❌ **i8k Interface**: `/proc/i8k` not exposed by kernel
- ❌ **i8kctl Commands**: Module doesn't respond to fan control commands

### What We're Investigating
- 🔍 **ACPI Methods**: Testing various ACPI fan control methods
- 🔍 **SMM Access**: Different dell-smm-hwmon parameters
- 🔍 **EC Port Access**: Direct embedded controller communication
- 🔍 **Firmware Dumps**: Analyzing DSDT and firmware interfaces

## 🧪 Experimental Results

### Test Session 1: Basic PWM Interface
**Date**: [To be filled]
**System**: Alienware M18, Kernel 6.11.0-26-generic

**Method**: Direct PWM write attempt
```bash
echo 255 | sudo tee /sys/class/hwmon/hwmon0/pwm1
```

**Result**: ❌ Permission denied
**RPM Change**: None
**Kernel Logs**: No relevant messages

**Conclusion**: Direct PWM write is blocked by EC

### Test Session 2: i8k Module Testing
**Date**: [To be filled]
**System**: Alienware M18, Kernel 6.11.0-26-generic

**Method**: Load i8k with force=1
```bash
sudo modprobe i8k force=1
i8kctl fan
```

**Result**: ❌ Module loads but no fan control
**RPM Change**: None
**Kernel Logs**: Module loaded successfully

**Conclusion**: i8k interface not functional on this model

### Test Session 3: dell-smm-hwmon Parameters
**Date**: [To be filled]
**System**: Alienware M18, Kernel 6.11.0-26-generic

**Methods Tested**:
- `force=1`
- `ignore_dmi=1`
- `restricted=0`

**Result**: 🔍 In progress
**RPM Change**: TBD
**Kernel Logs**: TBD

**Conclusion**: TBD

## 🔬 Technical Analysis

### Embedded Controller Architecture
The Alienware M18 uses a Dell-specific embedded controller that:
1. **Monitors thermal sensors** and adjusts fan speeds automatically
2. **Blocks direct PWM access** to prevent user interference
3. **Responds to ACPI methods** for system-level control
4. **Uses SMM (System Management Mode)** for secure operations

### Potential Bypass Methods

#### Method A: ACPI Method Override
**Theory**: Some ACPI methods might bypass EC restrictions
**Status**: 🔍 Testing needed
**Commands**:
```bash
echo "_SB.PCI0.LPCB.EC.FAN" | sudo tee /proc/acpi/call
```

#### Method B: SMM Parameter Manipulation
**Theory**: dell-smm-hwmon parameters might unlock control
**Status**: 🔍 Testing needed
**Commands**:
```bash
sudo modprobe dell-smm-hwmon force=1 ignore_dmi=1
```

#### Method C: Direct EC Communication
**Theory**: Direct port access might bypass kernel restrictions
**Status**: 🔍 Testing needed
**Commands**:
```bash
sudo dd if=/dev/port bs=1 count=1 skip=0x62
```

#### Method D: Firmware Reverse Engineering
**Theory**: DSDT analysis might reveal hidden methods
**Status**: 🔍 Analysis needed
**Commands**:
```bash
sudo cat /sys/firmware/acpi/tables/DSDT > dsdt_table.dat
iasl -d dsdt_table.dat
```

## 📈 Progress Tracking

### Completed Tests
- [ ] Basic PWM interface testing
- [ ] i8k module testing
- [ ] dell-smm-hwmon parameter testing
- [ ] ACPI method testing
- [ ] EC port access testing
- [ ] DSDT analysis
- [ ] Stress testing with monitoring

### Pending Tests
- [ ] Advanced ACPI method combinations
- [ ] Custom kernel module development
- [ ] Firmware modification attempts
- [ ] Cross-model compatibility testing

### Success Metrics
- [ ] Achieve manual fan speed control
- [ ] Maintain system stability
- [ ] Document working method
- [ ] Create user-friendly script
- [ ] Test on multiple models

## 🎯 Next Steps

### Immediate Actions
1. **Run comprehensive EC probe** using `./scripts/ec_probe.sh`
2. **Analyze DSDT tables** for fan control methods
3. **Test all ACPI methods** systematically
4. **Document all findings** in this file

### Medium-term Goals
1. **Develop custom kernel module** if needed
2. **Create user-friendly fan control script**
3. **Test on multiple Alienware models**
4. **Publish findings** for community use

### Long-term Vision
1. **Open-source fan control solution** for all Alienware systems
2. **Integration with desktop environments** (GNOME, KDE)
3. **Cross-distribution compatibility**
4. **Community-driven development**

## 📚 References

### Technical Documentation
- [Dell SMM Hardware Monitor Documentation](https://www.kernel.org/doc/html/latest/hwmon/dell-smm-hwmon.html)
- [i8k Module Documentation](https://www.kernel.org/doc/html/latest/hwmon/i8k.html)
- [ACPI Specification](https://uefi.org/specifications)

### Community Resources
- [Linux Hardware Database](https://linux-hardware.org/)
- [Arch Linux Wiki - Fan Control](https://wiki.archlinux.org/title/Fan_speed_control)
- [Ubuntu Forums - Alienware](https://ubuntuforums.org/forumdisplay.php?f=331)

### Related Projects
- [nbfc](https://github.com/hirschmann/nbfc) - NoteBook FanControl
- [fancontrol](https://github.com/lm-sensors/lm-sensors) - LM-Sensors fan control
- [i8kutils](https://github.com/vitorafsr/i8kutils) - i8k utilities

---

**Last Updated**: [To be filled]
**Next Review**: [To be filled] 