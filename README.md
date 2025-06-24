# 🔥 Alienware Linux Fan Control Hack

**Reverse-engineering Dell's EC (Embedded Controller) lockout to unlock manual fan control on Alienware systems running Linux.**

## 🎯 Mission

This project aims to bypass Dell's embedded controller restrictions and provide open-source fan control solutions for Alienware laptops on Linux. By documenting EC responses, PWM behavior, and successful bypass methods, we're building a shared knowledgebase for the Linux gaming community.

## 📊 Current Status Matrix

| Feature | Status | Details |
|---------|--------|---------|
| `fan1_input` readable | ✅ **WORKING** | 1768 RPM idle confirmed |
| `fan2_input` readable | ✅ **WORKING** | 1823 RPM idle confirmed |
| `fan3_input` readable | ✅ **WORKING** | 0 RPM (inactive) |
| `fan4_input` readable | ✅ **WORKING** | 0 RPM (inactive) |
| `pwm1` writable | ✅ **WORKING** | Direct PWM control confirmed |
| `pwm2` writable | ✅ **WORKING** | Direct PWM control confirmed |
| `pwm3` writable | ✅ **WORKING** | Direct PWM control confirmed |
| `pwm1_enable` exists | ❌ **MISSING** | Not exposed by kernel |
| `/proc/i8k` | ❌ **MISSING** | Not available |
| `i8kctl fan` | ❌ **BLOCKED** | Kernel doesn't expose |
| EC auto-ramp | ✅ **WORKING** | Confirmed via stress-ng |
| BIOS fan override | ✅ **WORKING** | Full speed if enabled |
| **Fan Control Script** | ✅ **WORKING** | `./scripts/fan_control.sh` |

## 🛠️ Quick Start

### 1. System Validation
```bash
# Check detected PWM/fan interfaces
ls /sys/class/hwmon/hwmon*/ | grep -i pwm

# Monitor fan speeds in real-time
watch -n1 'sensors | grep -i fan'

# Check for Dell modules
lsmod | grep dell
modprobe -v dell-smm-hwmon force=1
modprobe -v i8k force=1
```

### 2. Enable Debug Logging
```bash
# Setup logging directory
sudo mkdir -p /var/log/fan_debug/
sudo touch /var/log/fan_debug/ec_trace.log

# Start monitoring
./scripts/fanwatch.sh
```

### 3. Run EC Probe
```bash
# Generate system dump
./scripts/ec_probe.sh

# Check results
cat /var/log/fan_debug/ec_dump.txt
```

### 4. Control Your Fans! 🎉
```bash
# Show current status
sudo ./scripts/fan_control.sh status

# Set silent mode (25% PWM)
sudo ./scripts/fan_control.sh silent

# Set normal mode (50% PWM)
sudo ./scripts/fan_control.sh normal

# Set performance mode (75% PWM)
sudo ./scripts/fan_control.sh performance

# Set max mode (100% PWM)
sudo ./scripts/fan_control.sh max

# Auto mode (temperature-based)
sudo ./scripts/fan_control.sh auto
```

## 🧪 Experimental Methods

### ACPI DSDT Analysis
```bash
# Extract ACPI tables
sudo cat /sys/firmware/acpi/tables/DSDT > dsdt_table.dat

# Decompile (requires iasl)
iasl -d dsdt_table.dat

# Search for fan references
grep -i fan dsdt_table.dsl
```

### Firmware Dumps
```bash
# DMIDecode dump
sudo dmidecode > ec_dump.txt

# Kernel EC messages
sudo dmesg | grep -i ec
```

### EC Register Discovery
```bash
# Run EC poke script to discover additional registers
sudo python3 scripts/ec_poke_watch.py
```

## 📁 Project Structure

```
alienware-linux-fan-hack/
├── scripts/           # Logging, probes, watchdogs
│   ├── fan_control.sh # 🎉 WORKING fan control script
│   ├── fanwatch.sh    # Monitoring and logging
│   ├── ec_probe.sh    # Comprehensive EC probe
│   └── ec_poke_watch.py # EC register discovery
├── docs/              # Findings, models, screenshots  
├── experimental/      # ACPI dumps, firmware decoding
├── service/           # systemd scripts
└── README.md          # This file
```

## 🔬 Contributing

**Every test matters!** When you test a fan control method, please log:

- Timestamp
- Module version (`uname -a`, `lsmod`)
- Sensors output
- PWM path attempted (`/sys/class/hwmon/hwmonX/pwmY`)
- Whether RPM changed
- BIOS thermal mode at boot
- Kernel logs (`dmesg -T | grep fan`)

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 🎮 Supported Models

- **Alienware M18** (✅ **WORKING** - 4 fans discovered and controlled)
- **Alienware M17** (Testing needed)
- **Alienware M15** (Testing needed)
- **Other Dell Gaming** (Community reports)

## 🚀 Roadmap

- [x] Document all EC probe methods
- [x] Reverse-engineer PWM control paths
- [x] Develop reliable fan control script
- [ ] Create systemd service
- [ ] Build GTK/CLI GUI
- [ ] Support multiple Alienware models

## ⚠️ Disclaimer

This project involves reverse-engineering proprietary hardware. Use at your own risk. We are not responsible for any damage to your system.

## 🤝 Community

- **GitHub Issues**: Report findings, ask questions
- **Discussions**: Share successful methods
- **Wiki**: Document model-specific approaches

---

**🔥 SUCCESS! We've unlocked fan control on Alienware M18! 🎉**

*Last updated: 2025-06-24* 