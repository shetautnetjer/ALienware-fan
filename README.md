# 🔥 Alienware Linux Fan Control Hack

**Reverse-engineering Dell's EC (Embedded Controller) lockout to unlock manual fan control on Alienware systems running Linux.**

## 🎯 Mission

This project aims to bypass Dell's embedded controller restrictions and provide open-source fan control solutions for Alienware laptops on Linux. By documenting EC responses, PWM behavior, and successful bypass methods, we're building a shared knowledgebase for the Linux gaming community.

## 📊 Current Status Matrix

| Feature | Status | Details |
|---------|--------|---------|
| `fan1_input` readable | ✅ **WORKING** | 1320 RPM idle confirmed |
| `pwm1` writable | ❌ **BLOCKED** | Exists but not writable |
| `pwm1_enable` exists | ❌ **MISSING** | Not exposed by kernel |
| `/proc/i8k` | ❌ **MISSING** | Not available |
| `i8kctl fan` | ❌ **BLOCKED** | Kernel doesn't expose |
| EC auto-ramp | ✅ **WORKING** | Confirmed via stress-ng |
| BIOS fan override | ✅ **WORKING** | Full speed if enabled |

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

## 📁 Project Structure

```
alienware-linux-fan-hack/
├── scripts/           # Logging, probes, watchdogs
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

- **Alienware M18** (Primary target)
- **Alienware M17** (Testing needed)
- **Alienware M15** (Testing needed)
- **Other Dell Gaming** (Community reports)

## 🚀 Roadmap

- [ ] Document all EC probe methods
- [ ] Reverse-engineer PWM control paths
- [ ] Develop reliable fan control script
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

**🔥 We're pioneering something few people are touching — and it can help hundreds of other Linux users!**

*Last updated: $(date)* 