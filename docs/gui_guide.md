# 🖥️ Alienware Fan Control GUI Guide

This guide covers the production-grade GUI for the Alienware fan control project, providing easy-to-use interfaces for monitoring and controlling your laptop's cooling system.

## 🚀 Quick Start

### Setup
```bash
# Run the setup script
./setup_gui.sh

# Or install manually
sudo apt install python3-pyqt5 python3-tk python3-psutil
```

### Launch
```bash
# Smart launcher (recommended)
sudo ./alienfan_gui.sh

# Specific GUI versions
sudo ./alienfan_gui_pyqt.sh    # PyQt5 version
sudo ./alienfan_gui_tkinter.sh # Tkinter version
```

## 📋 GUI Features

### 🎛️ Dashboard Tab
The main interface showing real-time system monitoring:

#### Temperature Sensors
- **Live Display**: Real-time temperature readings in °C
- **Color Coding**: 
  - 🟢 Green: < 50°C (Cool)
  - 🟠 Orange: 50-70°C (Warm)
  - 🔴 Red: 70-85°C (Hot)
  - 🟣 Purple: > 85°C (Critical)
- **Progress Bars**: Visual temperature indicators
- **Sensor Labels**: Human-readable names (CPU Package, GPU, etc.)

#### Fan Control
- **RPM Monitoring**: Live fan speed readings
- **Control Modes**:
  - **Auto**: BIOS-controlled (default)
  - **Manual**: User-defined PWM (0-255)
  - **Full Speed**: Maximum cooling (PWM 255)
- **PWM Sliders**: Direct control over fan speeds
- **Status Indicators**: Real-time feedback on control operations

### ⚙️ Presets Tab
Quick access to predefined fan configurations:

#### Built-in Presets
- **Quiet Mode** (PWM 64): Minimal noise for light workloads
- **Balanced** (PWM 128): Good balance between noise and cooling
- **Performance** (PWM 192): Enhanced cooling for gaming
- **Max Cooling** (PWM 255): Maximum performance for stress testing
- **Gaming** (PWM 200): Optimized for gaming workloads
- **Stress Test** (PWM 255): Maximum cooling for benchmarks

#### Custom Control
- **Global PWM Slider**: Control all fans simultaneously
- **Apply Button**: Set custom PWM value to all controllable fans
- **Status Feedback**: Real-time confirmation of operations

### 💻 System Info Tab
Hardware and system information display:

#### System Details
- **CPU**: Processor model and specifications
- **Memory**: Total RAM capacity
- **Operating System**: Distribution and version
- **Hardware**: Additional system information

### 📝 Log Tab
Real-time system logging and diagnostics:

#### Log Features
- **Timestamped Entries**: All events with precise timing
- **Error Reporting**: Detailed error messages and diagnostics
- **Operation Logging**: Fan control operations and results
- **System Events**: Hardware detection and status changes

## 🎯 Usage Scenarios

### Daily Use
1. **Launch GUI**: `sudo ./alienfan_gui.sh`
2. **Monitor Temperatures**: Check Dashboard tab for system health
3. **Use Auto Mode**: Let BIOS handle fan control (recommended)
4. **Apply Presets**: Use Presets tab for quick adjustments

### Gaming
1. **Select Gaming Preset**: Click "Gaming" in Presets tab
2. **Monitor GPU Temperature**: Watch GPU temp in Dashboard
3. **Adjust if Needed**: Use Manual mode for fine-tuning
4. **Return to Auto**: Switch back to Auto mode when done

### Stress Testing
1. **Apply Max Cooling**: Use "Max Cooling" or "Stress Test" preset
2. **Monitor All Sensors**: Watch all temperature readings
3. **Check Fan Speeds**: Ensure fans are running at full speed
4. **Log Results**: Review Log tab for any issues

### Troubleshooting
1. **Check Log Tab**: Look for error messages
2. **Verify Permissions**: Ensure running as root
3. **Test Individual Fans**: Use Manual mode to test each fan
4. **Refresh Devices**: Click "Refresh Devices" if sensors aren't detected

## 🔧 Configuration

### GUI Configuration File (`gui_config.json`)

```json
{
    "presets": {
        "quiet": {
            "name": "Quiet Mode",
            "description": "Minimal fan noise for light workloads",
            "pwm_value": 64,
            "auto_threshold": 70
        }
    },
    "settings": {
        "update_interval": 2,
        "temperature_warning": 80,
        "temperature_critical": 90
    },
    "sensor_labels": {
        "coretemp": {
            "temp1": "CPU Package",
            "temp2": "CPU Core 1"
        },
        "dell_smm": {
            "fan1": "CPU Fan",
            "fan2": "GPU Fan"
        }
    }
}
```

### Customizing Presets
1. **Edit Config File**: Modify `gui_config.json`
2. **Add New Presets**: Define custom PWM values and thresholds
3. **Restart GUI**: Changes take effect on next launch
4. **Test Presets**: Verify new presets work correctly

## 🛠️ Troubleshooting

### Common Issues

#### GUI Won't Start
```bash
# Check dependencies
python3 -c "import PyQt5.QtWidgets"  # PyQt5
python3 -c "import tkinter"          # Tkinter

# Install missing dependencies
sudo apt install python3-pyqt5 python3-tk
```

#### No Fan Control
```bash
# Check permissions
sudo ./alienfan_gui.sh

# Verify hwmon access
ls -la /sys/class/hwmon/hwmon*/pwm*

# Test manual control
echo 128 | sudo tee /sys/class/hwmon/hwmon7/pwm1
```

#### Sensors Not Detected
```bash
# Refresh devices in GUI
# Or restart the application

# Check hwmon devices manually
ls /sys/class/hwmon/
cat /sys/class/hwmon/hwmon*/name
```

#### High CPU Usage
- **Reduce Update Interval**: Change from 2s to 5s in settings
- **Close Unused Tabs**: Minimize active monitoring
- **Use Tkinter Version**: Generally lighter than PyQt5

### Error Messages

#### "Permission Denied"
- Run GUI with `sudo`
- Check file permissions on hwmon devices
- Verify user is in appropriate groups

#### "No GUI Framework Available"
- Install PyQt5: `sudo apt install python3-pyqt5`
- Or install Tkinter: `sudo apt install python3-tk`
- Run setup script: `./setup_gui.sh`

#### "Fan Control Failed"
- Check if fan is controllable (PWM file exists)
- Verify PWM value is within range (0-255)
- Check for hardware limitations

## 🔒 Security Considerations

### Root Privileges
- **Required**: Fan control requires root access
- **Minimal**: GUI only accesses necessary hwmon files
- **Temporary**: Privileges only during GUI runtime

### File Access
- **Read-only**: Temperature and fan speed monitoring
- **Write access**: PWM control files only
- **No network**: GUI operates entirely locally

### Best Practices
- **Close when not needed**: Minimize time running as root
- **Monitor temperatures**: Don't disable fans completely
- **Test thoroughly**: Verify fan control before relying on it
- **Keep backups**: Save working configurations

## 📊 Performance Tips

### Optimization
- **Update Interval**: 2-5 seconds is optimal
- **Close Unused Tabs**: Reduce resource usage
- **Use Appropriate Preset**: Match workload to cooling needs
- **Monitor Logs**: Check for performance issues

### Monitoring
- **Temperature Thresholds**: Set appropriate warning levels
- **Fan Speed Monitoring**: Ensure fans respond to commands
- **System Load**: Watch for thermal throttling
- **Battery Impact**: Fan control affects power consumption

## 🔄 Updates and Maintenance

### Updating GUI
```bash
# Pull latest changes
git pull origin main

# Re-run setup if needed
./setup_gui.sh

# Test new features
sudo ./alienfan_gui.sh
```

### Configuration Backup
```bash
# Backup current config
cp gui_config.json gui_config.json.backup

# Restore if needed
cp gui_config.json.backup gui_config.json
```

### Log Management
- **Log Rotation**: Large logs can impact performance
- **Error Review**: Regularly check for recurring issues
- **Performance Monitoring**: Watch for GUI slowdowns

## 🤝 Contributing to GUI

### Development Setup
```bash
# Install development dependencies
pip3 install -r requirements.txt

# Run tests
python3 -m pytest tests/

# Format code
black *.py
```

### Adding Features
1. **Fork Repository**: Create your own copy
2. **Create Branch**: Work on feature branch
3. **Implement Changes**: Add new functionality
4. **Test Thoroughly**: Verify on target hardware
5. **Submit PR**: Create pull request with description

### GUI Guidelines
- **User-Friendly**: Intuitive interface design
- **Error Handling**: Graceful failure modes
- **Performance**: Efficient resource usage
- **Accessibility**: Support for different users
- **Documentation**: Clear usage instructions

## 📞 Support

### Getting Help
- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share experiences
- **Wiki**: Additional documentation and guides
- **Community**: Connect with other users

### Reporting Issues
When reporting GUI issues, include:
- **System Information**: OS, hardware, Python version
- **Error Messages**: Full error text and stack traces
- **Steps to Reproduce**: Detailed reproduction steps
- **Expected vs Actual**: What should happen vs what does
- **Logs**: Relevant log entries from Log tab

---

**Note**: This GUI is designed for Alienware laptops running Linux. Compatibility with other systems may vary. Always test thoroughly before relying on fan control for critical workloads. 