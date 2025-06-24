# 🚀 Quick Start Guide

**Get started with Alienware fan control reverse-engineering in 5 minutes!**

## ⚡ Immediate Actions

### 1. Install the Project
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run installation script
./scripts/install.sh
```

### 2. Run Your First Test
```bash
# Start comprehensive EC probe
./scripts/ec_probe.sh

# Monitor results in real-time
tail -f /var/log/fan_debug/ec_probe.log
```

### 3. Check Your System
```bash
# Quick system check
ls /sys/class/hwmon/hwmon*/ | grep -i pwm
sensors | grep -i fan
lsmod | grep dell
```

## 🔍 What to Test First

### Priority 1: PWM Interface
```bash
# Find PWM interfaces
ls /sys/class/hwmon/hwmon*/pwm*

# Test write access (this will likely fail, but we need to document it)
echo 255 | sudo tee /sys/class/hwmon/hwmon0/pwm1
```

### Priority 2: i8k Module
```bash
# Load i8k module
sudo modprobe i8k force=1

# Test i8kctl
i8kctl fan
i8kctl temp
```

### Priority 3: dell-smm-hwmon
```bash
# Load with different parameters
sudo modprobe dell-smm-hwmon force=1
sudo modprobe dell-smm-hwmon ignore_dmi=1
```

## 📊 Report Your Findings

### Create GitHub Issue
**Title**: `[M18] Initial system test - [BLOCKED/SUCCESS]`

**Body**:
```markdown
## System Info
- Model: [Your Alienware model]
- Kernel: $(uname -r)
- BIOS: $(sudo dmidecode -s bios-version)
- Distro: [Your distribution]

## Test Results
- PWM interfaces found: [List what you found]
- PWM write access: [BLOCKED/SUCCESS]
- i8k module: [WORKS/FAILS]
- dell-smm-hwmon: [WORKS/FAILS]

## Logs
[Attach relevant log files from /var/log/fan_debug/]

## Additional Notes
[Any observations or errors]
```

## 🎯 Next Steps

### If You're New to Linux
1. **Read the README.md** - Understand the project goals
2. **Run the basic tests** - Document what works/doesn't work
3. **Join discussions** - Ask questions, share findings
4. **Learn gradually** - Start with simple tests

### If You're Experienced
1. **Run comprehensive probe** - Use `./scripts/ec_probe.sh`
2. **Analyze DSDT tables** - Look for fan control methods
3. **Test ACPI methods** - Try different ACPI calls
4. **Contribute code** - Help develop solutions

### If You're a Developer
1. **Study the code** - Understand the current approach
2. **Run all tests** - Establish baseline
3. **Propose improvements** - Suggest new methods
4. **Write patches** - Contribute working solutions

## 🔧 Troubleshooting

### Common Issues

**Scripts not executable**:
```bash
chmod +x scripts/*.sh
```

**Permission denied on logs**:
```bash
sudo mkdir -p /var/log/fan_debug
sudo chown $USER:$USER /var/log/fan_debug
```

**Missing packages**:
```bash
sudo apt install lm-sensors dmidecode stress-ng acpica-tools
```

**Sensors not working**:
```bash
sudo sensors-detect --auto
```

### Getting Help
- **GitHub Issues**: Report problems and findings
- **GitHub Discussions**: Ask questions and share ideas
- **Documentation**: Check README.md and CONTRIBUTING.md

## 📈 Success Metrics

### What We're Looking For
- ✅ **PWM write access** - Can we control fan speed directly?
- ✅ **i8k functionality** - Does i8k work on your model?
- ✅ **ACPI methods** - Any fan-related ACPI methods?
- ✅ **EC responses** - How does EC react to different inputs?

### What to Document
- **Every test attempt** - Success or failure
- **System differences** - Model, kernel, BIOS variations
- **Error messages** - Exact error text and context
- **Unexpected behavior** - Anything that doesn't match expectations

## 🎮 Gaming Focus

### Why This Matters for Gamers
- **Better thermal management** - Prevent throttling during games
- **Custom fan curves** - Optimize for your gaming style
- **Noise control** - Balance performance and acoustics
- **Linux gaming** - Full Linux gaming experience

### Gaming-Specific Tests
```bash
# Test under gaming load
stress-ng --cpu 4 --io 2 --vm 1 --vm-bytes 1G &
./scripts/fanwatch.sh
```

## 🤝 Community

### How to Help
1. **Test on your system** - Every model helps
2. **Document findings** - Share what you discover
3. **Help others** - Answer questions in discussions
4. **Spread the word** - Tell other Alienware Linux users

### Recognition
- **Contributors** will be listed in project documentation
- **Successful methods** will be named after discoverers
- **Major breakthroughs** will be highlighted in releases
- **Community members** will be acknowledged in publications

---

**🔥 Ready to unlock fan control? Let's get started!**

*Remember: Every test, every log, every failure brings us closer to success!* 