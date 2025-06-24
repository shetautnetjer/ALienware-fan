#!/usr/bin/env python3
"""
🔥 Alienware Fan Control GUI - Enhanced Version
Production-grade GUI for monitoring and controlling Alienware laptop fans
Now includes EC-controlled fans (6 additional fans unlocked!)
"""

import sys
import os
import json
import time
import threading
import subprocess
from datetime import datetime
from typing import Dict, List, Optional, Tuple

try:
    from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                                QHBoxLayout, QGridLayout, QLabel, QComboBox, 
                                QSlider, QPushButton, QGroupBox, QTabWidget,
                                QProgressBar, QCheckBox, QSpinBox, QTextEdit,
                                QMessageBox, QFileDialog, QSystemTrayIcon,
                                QMenu, QAction, QFrame, QSplitter, QScrollArea,
                                QTableWidget, QTableWidgetItem, QHeaderView)
    from PyQt5.QtCore import QTimer, QThread, pyqtSignal, Qt, QSettings
    from PyQt5.QtGui import QFont, QIcon, QPalette, QColor, QPixmap
    PYQT_AVAILABLE = True
except ImportError:
    print("PyQt5 not available. Please install with: pip install PyQt5")
    sys.exit(1)

class FanController:
    """Enhanced backend controller for fan operations"""
    
    def __init__(self):
        self.hwmon_paths = self._discover_hwmon_devices()
        self.fan_devices = self._discover_fan_devices()
        self.temp_devices = self._discover_temp_devices()
        self.config = self._load_config()
        
        # EC fan control registers (newly unlocked fans)
        self.ec_fan_registers = {
            '24': 'GPU Fan',
            '28': 'VRM Fan',
            '2C': 'Exhaust Fan',
            '30': 'Chassis Fan',
            '34': 'Memory Fan',
            '38': 'Additional Fan 1',
            '3C': 'Additional Fan 2'
        }
        
    def _load_config(self) -> Dict:
        """Load configuration from JSON file"""
        config_file = "gui_config.json"
        if os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    return json.load(f)
            except:
                pass
        return {}
    
    def _discover_hwmon_devices(self) -> Dict[str, str]:
        """Discover all hwmon devices"""
        devices = {}
        hwmon_dir = "/sys/class/hwmon"
        
        if not os.path.exists(hwmon_dir):
            return devices
            
        for hwmon_name in os.listdir(hwmon_dir):
            hwmon_path = os.path.join(hwmon_dir, hwmon_name)
            if os.path.isdir(hwmon_path):
                name_file = os.path.join(hwmon_path, "name")
                if os.path.exists(name_file):
                    try:
                        with open(name_file, 'r') as f:
                            device_name = f.read().strip()
                        devices[hwmon_name] = device_name
                    except:
                        devices[hwmon_name] = hwmon_name
                else:
                    devices[hwmon_name] = hwmon_name
                    
        return devices
    
    def _discover_fan_devices(self) -> Dict[str, Dict]:
        """Discover fan devices and their capabilities"""
        fans = {}
        
        for hwmon_name, device_name in self.hwmon_paths.items():
            hwmon_path = f"/sys/class/hwmon/{hwmon_name}"
            
            # Find fan inputs
            fan_inputs = []
            fan_pwms = []
            
            for item in os.listdir(hwmon_path):
                if item.startswith("fan") and item.endswith("_input"):
                    fan_num = item[3:-6]  # Extract fan number
                    fan_inputs.append(fan_num)
                    
                    # Check if PWM control exists
                    pwm_file = os.path.join(hwmon_path, f"pwm{fan_num}")
                    if os.path.exists(pwm_file):
                        fan_pwms.append(fan_num)
            
            if fan_inputs:
                fans[hwmon_name] = {
                    'name': device_name,
                    'path': hwmon_path,
                    'fan_inputs': fan_inputs,
                    'fan_pwms': fan_pwms
                }
                
        return fans
    
    def _discover_temp_devices(self) -> Dict[str, Dict]:
        """Discover temperature sensors"""
        temps = {}
        
        for hwmon_name, device_name in self.hwmon_paths.items():
            hwmon_path = f"/sys/class/hwmon/{hwmon_name}"
            
            temp_inputs = []
            for item in os.listdir(hwmon_path):
                if item.startswith("temp") and item.endswith("_input"):
                    temp_num = item[4:-6]  # Extract temp number
                    temp_inputs.append(temp_num)
            
            if temp_inputs:
                temps[hwmon_name] = {
                    'name': device_name,
                    'path': hwmon_path,
                    'temp_inputs': temp_inputs
                }
                
        return temps
    
    def get_sensor_label(self, device_name: str, sensor_type: str, sensor_num: str) -> str:
        """Get human-readable label for sensor"""
        if 'sensor_labels' in self.config:
            if device_name in self.config['sensor_labels']:
                if sensor_type in self.config['sensor_labels'][device_name]:
                    return self.config['sensor_labels'][device_name][sensor_type]
        return f"{device_name} {sensor_type}{sensor_num}"
    
    def get_fan_speeds(self) -> Dict[str, Dict[str, int]]:
        """Get current fan speeds for all devices"""
        speeds = {}
        
        for hwmon_name, device_info in self.fan_devices.items():
            speeds[hwmon_name] = {}
            for fan_num in device_info['fan_inputs']:
                fan_file = os.path.join(device_info['path'], f"fan{fan_num}_input")
                try:
                    with open(fan_file, 'r') as f:
                        speed = int(f.read().strip())
                    speeds[hwmon_name][fan_num] = speed
                except:
                    speeds[hwmon_name][fan_num] = 0
                    
        return speeds
    
    def get_temperatures(self) -> Dict[str, Dict[str, float]]:
        """Get current temperatures for all devices"""
        temps = {}
        
        for hwmon_name, device_info in self.temp_devices.items():
            temps[hwmon_name] = {}
            for temp_num in device_info['temp_inputs']:
                temp_file = os.path.join(device_info['path'], f"temp{temp_num}_input")
                try:
                    with open(temp_file, 'r') as f:
                        temp_raw = int(f.read().strip())
                    temp_celsius = temp_raw / 1000.0
                    temps[hwmon_name][temp_num] = temp_celsius
                except:
                    temps[hwmon_name][temp_num] = 0.0
                    
        return temps
    
    def get_pwm_values(self) -> Dict[str, Dict[str, int]]:
        """Get current PWM values for all fans"""
        pwms = {}
        
        for hwmon_name, device_info in self.fan_devices.items():
            pwms[hwmon_name] = {}
            for fan_num in device_info['fan_pwms']:
                pwm_file = os.path.join(device_info['path'], f"pwm{fan_num}")
                try:
                    with open(pwm_file, 'r') as f:
                        pwm = int(f.read().strip())
                    pwms[hwmon_name][fan_num] = pwm
                except:
                    pwms[hwmon_name][fan_num] = 0
                    
        return pwms
    
    def get_ec_fan_pwms(self) -> Dict[str, int]:
        """Get current PWM values for EC-controlled fans"""
        ec_pwms = {}
        
        for register, fan_name in self.ec_fan_registers.items():
            try:
                result = subprocess.run(
                    f"sudo dd if=/dev/port bs=1 count=1 skip=$((0x{register})) 2>/dev/null | od -An -tu1",
                    shell=True, capture_output=True, text=True
                )
                if result.returncode == 0:
                    pwm = int(result.stdout.strip())
                else:
                    pwm = 0
                ec_pwms[register] = pwm
            except:
                ec_pwms[register] = 0
                
        return ec_pwms
    
    def set_pwm(self, hwmon_name: str, fan_num: str, pwm_value: int) -> bool:
        """Set PWM value for a specific fan"""
        if hwmon_name not in self.fan_devices:
            return False
            
        if fan_num not in self.fan_devices[hwmon_name]['fan_pwms']:
            return False
            
        pwm_file = os.path.join(self.fan_devices[hwmon_name]['path'], f"pwm{fan_num}")
        
        try:
            with open(pwm_file, 'w') as f:
                f.write(str(pwm_value))
            return True
        except:
            return False
    
    def set_ec_fan_pwm(self, register: str, pwm_value: int) -> bool:
        """Set PWM value for EC-controlled fan"""
        if register not in self.ec_fan_registers:
            return False
            
        try:
            # Convert decimal to hex
            pwm_hex = f"{pwm_value:02X}"
            
            # Write to EC register
            result = subprocess.run(
                f"echo -ne '\\x{pwm_hex}' | sudo dd of=/dev/port bs=1 count=1 seek=$((0x{register})) 2>/dev/null",
                shell=True, capture_output=True, text=True
            )
            return result.returncode == 0
        except:
            return False
    
    def set_all_pwm(self, pwm_value: int) -> bool:
        """Set all fans to the same PWM value"""
        success = True
        
        # Set hwmon fans
        for hwmon_name, device_info in self.fan_devices.items():
            for fan_num in device_info['fan_pwms']:
                if not self.set_pwm(hwmon_name, fan_num, pwm_value):
                    success = False
        
        # Set EC fans
        for register in self.ec_fan_registers.keys():
            if not self.set_ec_fan_pwm(register, pwm_value):
                success = False
                
        return success
    
    def apply_preset(self, preset_name: str) -> bool:
        """Apply a preset configuration"""
        presets = {
            'silent': 32,      # 12.5%
            'quiet': 64,       # 25%
            'normal': 128,     # 50%
            'performance': 192, # 75%
            'max': 255,        # 100%
            'gaming': 200,     # 78%
            'stress': 240      # 94%
        }
        
        if preset_name in presets:
            return self.set_all_pwm(presets[preset_name])
        return False
    
    def get_system_info(self) -> Dict:
        """Get system information"""
        info = {}
        
        try:
            # Kernel info
            result = subprocess.run(["uname", "-r"], capture_output=True, text=True)
            if result.returncode == 0:
                info['kernel'] = result.stdout.strip()
            
            # CPU info
            result = subprocess.run(["lscpu"], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'Model name:' in line:
                        info['cpu'] = line.split(':')[1].strip()
                        break
            
            # Memory info
            result = subprocess.run(["free", "-h"], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.split('\n')
                if len(lines) > 1:
                    mem_line = lines[1].split()
                    if len(mem_line) > 1:
                        info['memory'] = mem_line[1]
            
            # GPU info
            result = subprocess.run(["lspci"], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'VGA' in line or 'Display' in line:
                        info['gpu'] = line
                        break
            
            # Fan control info
            info['fan_control'] = {
                'hwmon_fans': len([f for device in self.fan_devices.values() for f in device['fan_pwms']]),
                'ec_fans': len(self.ec_fan_registers),
                'total_controllable': len([f for device in self.fan_devices.values() for f in device['fan_pwms']]) + len(self.ec_fan_registers)
            }
            
        except Exception as e:
            info['error'] = str(e)
            
        return info

class SensorMonitor(QThread):
    """Thread for monitoring sensors"""
    data_updated = pyqtSignal(dict, dict, dict)  # speeds, temps, pwms
    error_occurred = pyqtSignal(str)
    
    def __init__(self, controller: FanController):
        super().__init__()
        self.controller = controller
        self.running = True
        self.update_interval = 2
        
    def run(self):
        while self.running:
            try:
                speeds = self.controller.get_fan_speeds()
                temps = self.controller.get_temperatures()
                pwms = self.controller.get_pwm_values()
                self.data_updated.emit(speeds, temps, pwms)
            except Exception as e:
                self.error_occurred.emit(str(e))
            
            time.sleep(self.update_interval)
    
    def stop(self):
        self.running = False
    
    def set_update_interval(self, interval: int):
        self.update_interval = interval

class FanControlWidget(QWidget):
    """Enhanced widget for controlling individual fans"""
    
    def __init__(self, hwmon_name: str, fan_num: str, device_name: str, controller: FanController):
        super().__init__()
        self.hwmon_name = hwmon_name
        self.fan_num = fan_num
        self.device_name = device_name
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Fan label with better formatting
        fan_label = QLabel(self.controller.get_sensor_label(self.device_name, "fan", self.fan_num))
        fan_label.setFont(QFont("Arial", 10, QFont.Bold))
        fan_label.setStyleSheet("color: #2E86AB;")
        layout.addWidget(fan_label)
        
        # RPM display with larger font
        self.rpm_label = QLabel("RPM: --")
        self.rpm_label.setFont(QFont("Arial", 14, QFont.Bold))
        self.rpm_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.rpm_label)
        
        # Control mode
        mode_layout = QHBoxLayout()
        mode_layout.addWidget(QLabel("Mode:"))
        
        self.mode_combo = QComboBox()
        self.mode_combo.addItems(["Auto", "Manual", "Full Speed"])
        self.mode_combo.currentTextChanged.connect(self.on_mode_changed)
        mode_layout.addWidget(self.mode_combo)
        
        layout.addLayout(mode_layout)
        
        # PWM slider with better styling
        pwm_layout = QHBoxLayout()
        pwm_layout.addWidget(QLabel("PWM:"))
        
        self.pwm_slider = QSlider(Qt.Horizontal)
        self.pwm_slider.setRange(0, 255)
        self.pwm_slider.setValue(128)
        self.pwm_slider.valueChanged.connect(self.on_pwm_changed)
        self.pwm_slider.setStyleSheet("""
            QSlider::groove:horizontal {
                border: 1px solid #999999;
                height: 8px;
                background: #f0f0f0;
                border-radius: 4px;
            }
            QSlider::handle:horizontal {
                background: #2E86AB;
                border: 1px solid #5c6ac7;
                width: 18px;
                margin: -2px 0;
                border-radius: 9px;
            }
        """)
        pwm_layout.addWidget(self.pwm_slider)
        
        self.pwm_label = QLabel("128")
        self.pwm_label.setMinimumWidth(40)
        pwm_layout.addWidget(self.pwm_label)
        
        layout.addLayout(pwm_layout)
        
        # PWM progress bar with color coding
        self.pwm_bar = QProgressBar()
        self.pwm_bar.setRange(0, 255)
        self.pwm_bar.setValue(128)
        self.pwm_bar.setFormat("")
        layout.addWidget(self.pwm_bar)
        
        # Status indicator
        self.status_label = QLabel("Ready")
        self.status_label.setAlignment(Qt.AlignCenter)
        self.status_label.setStyleSheet("color: green; font-weight: bold;")
        layout.addWidget(self.status_label)
        
        self.setLayout(layout)
        
    def update_rpm(self, rpm: int):
        self.rpm_label.setText(f"RPM: {rpm:,}")
        
        # Color coding based on RPM
        if rpm == 0:
            self.rpm_label.setStyleSheet("color: red; font-weight: bold;")
        elif rpm < 1000:
            self.rpm_label.setStyleSheet("color: orange; font-weight: bold;")
        else:
            self.rpm_label.setStyleSheet("color: green; font-weight: bold;")
        
    def update_pwm(self, pwm: int):
        self.pwm_slider.setValue(pwm)
        self.pwm_label.setText(str(pwm))
        self.pwm_bar.setValue(pwm)
        
        # Color coding for PWM bar
        percentage = (pwm / 255) * 100
        if percentage < 30:
            color = "#4CAF50"  # Green
        elif percentage < 70:
            color = "#FF9800"  # Orange
        else:
            color = "#F44336"  # Red
            
        self.pwm_bar.setStyleSheet(f"""
            QProgressBar {{
                border: 2px solid grey;
                border-radius: 5px;
                text-align: center;
            }}
            QProgressBar::chunk {{
                background-color: {color};
                border-radius: 3px;
            }}
        """)
        
    def on_mode_changed(self, mode: str):
        if mode == "Auto":
            self.status_label.setText("Auto Mode")
            self.status_label.setStyleSheet("color: blue; font-weight: bold;")
        elif mode == "Manual":
            pwm_value = self.pwm_slider.value()
            if self.controller.set_pwm(self.hwmon_name, self.fan_num, pwm_value):
                self.status_label.setText("Manual Mode")
                self.status_label.setStyleSheet("color: green; font-weight: bold;")
            else:
                self.status_label.setText("Error")
                self.status_label.setStyleSheet("color: red; font-weight: bold;")
        elif mode == "Full Speed":
            if self.controller.set_pwm(self.hwmon_name, self.fan_num, 255):
                self.status_label.setText("Full Speed")
                self.status_label.setStyleSheet("color: red; font-weight: bold;")
            else:
                self.status_label.setText("Error")
                self.status_label.setStyleSheet("color: red; font-weight: bold;")
            
    def on_pwm_changed(self, value: int):
        self.pwm_label.setText(str(value))
        self.pwm_bar.setValue(value)
        if self.mode_combo.currentText() == "Manual":
            if self.controller.set_pwm(self.hwmon_name, self.fan_num, value):
                self.status_label.setText("Manual Mode")
                self.status_label.setStyleSheet("color: green; font-weight: bold;")
            else:
                self.status_label.setText("Error")
                self.status_label.setStyleSheet("color: red; font-weight: bold;")

class TemperatureWidget(QWidget):
    """Enhanced widget for displaying temperature sensors"""
    
    def __init__(self, hwmon_name: str, temp_num: str, device_name: str, controller: FanController):
        super().__init__()
        self.hwmon_name = hwmon_name
        self.temp_num = temp_num
        self.device_name = device_name
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Temperature label
        temp_label = QLabel(self.controller.get_sensor_label(self.device_name, "temp", self.temp_num))
        temp_label.setFont(QFont("Arial", 10, QFont.Bold))
        temp_label.setStyleSheet("color: #A23B72;")
        layout.addWidget(temp_label)
        
        # Temperature display
        self.temp_label = QLabel("--°C")
        self.temp_label.setFont(QFont("Arial", 18, QFont.Bold))
        self.temp_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.temp_label)
        
        # Temperature progress bar
        self.temp_bar = QProgressBar()
        self.temp_bar.setRange(0, 100)
        self.temp_bar.setValue(0)
        self.temp_bar.setFormat("")
        layout.addWidget(self.temp_bar)
        
        # Status indicator
        self.status_label = QLabel("Normal")
        self.status_label.setAlignment(Qt.AlignCenter)
        self.status_label.setStyleSheet("color: green; font-weight: bold;")
        layout.addWidget(self.status_label)
        
        self.setLayout(layout)
        
    def update_temperature(self, temp: float):
        self.temp_label.setText(f"{temp:.1f}°C")
        self.temp_bar.setValue(int(temp))
        
        # Color coding and status based on temperature
        if temp < 50:
            color = "#4CAF50"  # Green
            status = "Cool"
        elif temp < 70:
            color = "#FF9800"  # Orange
            status = "Warm"
        elif temp < 85:
            color = "#F44336"  # Red
            status = "Hot"
        else:
            color = "#9C27B0"  # Purple
            status = "Critical"
            
        self.temp_label.setStyleSheet(f"color: {color}; font-weight: bold;")
        self.status_label.setText(status)
        self.status_label.setStyleSheet(f"color: {color}; font-weight: bold;")
        
        # Color coding for temperature bar
        self.temp_bar.setStyleSheet(f"""
            QProgressBar {{
                border: 2px solid grey;
                border-radius: 5px;
                text-align: center;
            }}
            QProgressBar::chunk {{
                background-color: {color};
                border-radius: 3px;
            }}
        """)

class PresetWidget(QWidget):
    """Enhanced widget for managing fan presets"""
    
    def __init__(self, controller: FanController):
        super().__init__()
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Preset buttons with better styling
        preset_group = QGroupBox("Quick Presets")
        preset_layout = QGridLayout()
        
        presets = [
            ("Quiet Mode", "quiet", "#4CAF50"),
            ("Balanced", "balanced", "#2196F3"),
            ("Performance", "performance", "#FF9800"),
            ("Max Cooling", "max", "#F44336"),
            ("Gaming", "gaming", "#9C27B0"),
            ("Stress Test", "stress", "#E91E63")
        ]
        
        row = 0
        col = 0
        for name, preset_id, color in presets:
            btn = QPushButton(name)
            btn.setStyleSheet(f"""
                QPushButton {{
                    background-color: {color};
                    color: white;
                    border: none;
                    padding: 10px;
                    border-radius: 5px;
                    font-weight: bold;
                }}
                QPushButton:hover {{
                    background-color: {color}dd;
                }}
                QPushButton:pressed {{
                    background-color: {color}aa;
                }}
            """)
            btn.clicked.connect(lambda checked, pid=preset_id: self.apply_preset(pid))
            preset_layout.addWidget(btn, row, col)
            col += 1
            if col > 2:  # 3 columns
                col = 0
                row += 1
        
        preset_group.setLayout(preset_layout)
        layout.addWidget(preset_group)
        
        # Custom PWM control
        custom_group = QGroupBox("Custom Control")
        custom_layout = QVBoxLayout()
        
        pwm_layout = QHBoxLayout()
        pwm_layout.addWidget(QLabel("All Fans PWM:"))
        
        self.custom_pwm_slider = QSlider(Qt.Horizontal)
        self.custom_pwm_slider.setRange(0, 255)
        self.custom_pwm_slider.setValue(128)
        self.custom_pwm_slider.valueChanged.connect(self.on_custom_pwm_changed)
        self.custom_pwm_slider.setStyleSheet("""
            QSlider::groove:horizontal {
                border: 1px solid #999999;
                height: 8px;
                background: #f0f0f0;
                border-radius: 4px;
            }
            QSlider::handle:horizontal {
                background: #2E86AB;
                border: 1px solid #5c6ac7;
                width: 18px;
                margin: -2px 0;
                border-radius: 9px;
            }
        """)
        pwm_layout.addWidget(self.custom_pwm_slider)
        
        self.custom_pwm_label = QLabel("128")
        self.custom_pwm_label.setMinimumWidth(40)
        pwm_layout.addWidget(self.custom_pwm_label)
        
        custom_layout.addLayout(pwm_layout)
        
        apply_btn = QPushButton("Apply to All Fans")
        apply_btn.setStyleSheet("""
            QPushButton {
                background-color: #2E86AB;
                color: white;
                border: none;
                padding: 10px;
                border-radius: 5px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #2E86ABdd;
            }
        """)
        apply_btn.clicked.connect(self.apply_custom_pwm)
        custom_layout.addWidget(apply_btn)
        
        custom_group.setLayout(custom_layout)
        layout.addWidget(custom_group)
        
        # Status display
        self.status_label = QLabel("Ready")
        self.status_label.setAlignment(Qt.AlignCenter)
        self.status_label.setStyleSheet("color: green; font-weight: bold; padding: 10px;")
        layout.addWidget(self.status_label)
        
        self.setLayout(layout)
        
    def apply_preset(self, preset: str):
        if self.controller.apply_preset(preset):
            self.status_label.setText(f"Applied {preset} preset")
            self.status_label.setStyleSheet("color: green; font-weight: bold; padding: 10px;")
        else:
            self.status_label.setText("Error applying preset")
            self.status_label.setStyleSheet("color: red; font-weight: bold; padding: 10px;")
            
    def on_custom_pwm_changed(self, value: int):
        self.custom_pwm_label.setText(str(value))
        
    def apply_custom_pwm(self):
        value = self.custom_pwm_slider.value()
        if self.controller.set_all_pwm(value):
            self.status_label.setText(f"Applied PWM {value} to all fans")
            self.status_label.setStyleSheet("color: green; font-weight: bold; padding: 10px;")
        else:
            self.status_label.setText("Error applying PWM")
            self.status_label.setStyleSheet("color: red; font-weight: bold; padding: 10px;")

class SystemInfoWidget(QWidget):
    """Widget for displaying system information"""
    
    def __init__(self, controller: FanController):
        super().__init__()
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # System info table
        self.info_table = QTableWidget()
        self.info_table.setColumnCount(2)
        self.info_table.setHorizontalHeaderLabels(["Property", "Value"])
        self.info_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.info_table.setAlternatingRowColors(True)
        
        layout.addWidget(self.info_table)
        
        # Refresh button
        refresh_btn = QPushButton("Refresh System Info")
        refresh_btn.clicked.connect(self.refresh_info)
        layout.addWidget(refresh_btn)
        
        self.setLayout(layout)
        self.refresh_info()
        
    def refresh_info(self):
        info = self.controller.get_system_info()
        
        self.info_table.setRowCount(len(info))
        
        for i, (key, value) in enumerate(info.items()):
            self.info_table.setItem(i, 0, QTableWidgetItem(key.title()))
            self.info_table.setItem(i, 1, QTableWidgetItem(str(value)))

class ECFanControlWidget(QWidget):
    """Widget for controlling EC-controlled fans"""
    
    def __init__(self, register: str, fan_name: str, controller: FanController):
        super().__init__()
        self.register = register
        self.fan_name = fan_name
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # Fan name and register
        name_label = QLabel(f"{self.fan_name}")
        name_label.setAlignment(Qt.AlignCenter)
        name_label.setFont(QFont("Arial", 10, QFont.Bold))
        layout.addWidget(name_label)
        
        reg_label = QLabel(f"Reg: 0x{self.register}")
        reg_label.setAlignment(Qt.AlignCenter)
        reg_label.setStyleSheet("color: gray; font-size: 9px;")
        layout.addWidget(reg_label)
        
        # PWM slider
        self.pwm_slider = QSlider(Qt.Vertical)
        self.pwm_slider.setRange(0, 255)
        self.pwm_slider.setValue(128)
        self.pwm_slider.setTickPosition(QSlider.TicksBothSides)
        self.pwm_slider.setTickInterval(64)
        self.pwm_slider.valueChanged.connect(self.on_pwm_changed)
        layout.addWidget(self.pwm_slider)
        
        # PWM value label
        self.pwm_label = QLabel("128")
        self.pwm_label.setAlignment(Qt.AlignCenter)
        self.pwm_label.setStyleSheet("font-weight: bold; color: blue;")
        layout.addWidget(self.pwm_label)
        
        # Quick preset buttons
        preset_layout = QHBoxLayout()
        
        presets = [
            ("25%", 64),
            ("50%", 128),
            ("75%", 192),
            ("100%", 255)
        ]
        
        for name, value in presets:
            btn = QPushButton(name)
            btn.setMaximumWidth(40)
            btn.clicked.connect(lambda checked, v=value: self.set_pwm(v))
            preset_layout.addWidget(btn)
        
        layout.addLayout(preset_layout)
        
    def on_pwm_changed(self, value: int):
        """Handle PWM slider change"""
        self.pwm_label.setText(str(value))
        self.controller.set_ec_fan_pwm(self.register, value)
        
    def set_pwm(self, value: int):
        """Set PWM value"""
        self.pwm_slider.setValue(value)
        
    def update_pwm(self, pwm: int):
        """Update PWM display"""
        self.pwm_slider.setValue(pwm)

class AlienwareFanGUI(QMainWindow):
    """Enhanced main GUI window for Alienware fan control"""
    
    def __init__(self):
        super().__init__()
        self.controller = FanController()
        self.fan_widgets = {}
        self.temp_widgets = {}
        self.setup_ui()
        self.setup_monitoring()
        self.setup_system_tray()
        
    def setup_ui(self):
        self.setWindowTitle("🔥 Alienware Fan Control - Enhanced (9 Fans)")
        self.setGeometry(100, 100, 1400, 900)
        
        # Set application icon (if available)
        try:
            self.setWindowIcon(QIcon("fan-icon.png"))
        except:
            pass
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Main layout
        main_layout = QVBoxLayout()
        
        # Title
        title = QLabel("🔥 Alienware Fan Control - Enhanced")
        title.setFont(QFont("Arial", 18, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("color: #FF6B35; margin: 10px;")
        main_layout.addWidget(title)
        
        # Subtitle with fan count
        subtitle = QLabel("🎛️ Control All 9 Fans: 3 hwmon7 + 6 EC-controlled")
        subtitle.setFont(QFont("Arial", 12))
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setStyleSheet("color: #4ECDC4; margin-bottom: 10px;")
        main_layout.addWidget(subtitle)
        
        # Create tab widget
        self.tab_widget = QTabWidget()
        main_layout.addWidget(self.tab_widget)
        
        # Create tabs
        self.tab_widget.addTab(self.create_fan_control_tab(), "🎛️ Fan Control")
        self.tab_widget.addTab(self.create_ec_control_tab(), "🔌 EC Fans (New)")
        self.tab_widget.addTab(self.create_monitoring_tab(), "📊 Monitoring")
        self.tab_widget.addTab(self.create_presets_tab(), "⚙️ Presets")
        self.tab_widget.addTab(self.create_system_tab(), "💻 System Info")
        
        # Status bar
        self.statusBar().showMessage("Ready - All 9 fans controllable")
        
    def create_fan_control_tab(self):
        """Create tab for fan control"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Create scroll areas for better layout
        temp_scroll = QScrollArea()
        temp_widget = QWidget()
        self.temp_layout = QGridLayout()
        temp_widget.setLayout(self.temp_layout)
        temp_scroll.setWidget(temp_widget)
        temp_scroll.setWidgetResizable(True)
        temp_scroll.setMaximumHeight(200)
        
        fan_scroll = QScrollArea()
        fan_widget = QWidget()
        self.fan_layout = QGridLayout()
        fan_widget.setLayout(self.fan_layout)
        fan_scroll.setWidget(fan_widget)
        fan_scroll.setWidgetResizable(True)
        
        # Temperature section
        temp_group = QGroupBox("Temperature Sensors")
        temp_group_layout = QVBoxLayout()
        temp_group_layout.addWidget(temp_scroll)
        temp_group.setLayout(temp_group_layout)
        layout.addWidget(temp_group)
        
        # Fan control section
        fan_group = QGroupBox("Fan Control")
        fan_group_layout = QVBoxLayout()
        fan_group_layout.addWidget(fan_scroll)
        fan_group.setLayout(fan_group_layout)
        layout.addWidget(fan_group)
        
        # Setup devices
        self.setup_devices()
        
        return widget
    
    def create_ec_control_tab(self):
        """Create tab for EC-controlled fans"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Title
        title = QLabel("🔌 EC-Controlled Fans (Newly Unlocked!)")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("color: #FF6B35; margin: 10px;")
        layout.addWidget(title)
        
        # Description
        desc = QLabel("These 6 fans were unlocked through EC register access")
        desc.setAlignment(Qt.AlignCenter)
        desc.setStyleSheet("color: gray; margin-bottom: 20px;")
        layout.addWidget(desc)
        
        # EC fan controls grid
        ec_layout = QGridLayout()
        
        self.ec_widgets = {}
        row = 0
        col = 0
        max_cols = 3
        
        for register, fan_name in self.controller.ec_fan_registers.items():
            ec_widget = ECFanControlWidget(register, fan_name, self.controller)
            self.ec_widgets[register] = ec_widget
            ec_layout.addWidget(ec_widget, row, col)
            
            col += 1
            if col >= max_cols:
                col = 0
                row += 1
        
        layout.addLayout(ec_layout)
        
        # Control buttons
        button_layout = QHBoxLayout()
        
        # Quick preset buttons for all EC fans
        ec_presets = [
            ("Silent (25%)", 64),
            ("Normal (50%)", 128),
            ("Performance (75%)", 192),
            ("Maximum (100%)", 255)
        ]
        
        for name, pwm in ec_presets:
            btn = QPushButton(name)
            btn.clicked.connect(lambda checked, p=pwm: self.set_all_ec_fans(p))
            button_layout.addWidget(btn)
        
        layout.addLayout(button_layout)
        
        # Individual control
        individual_group = QGroupBox("Individual EC Fan Control")
        individual_layout = QHBoxLayout(individual_group)
        
        # Register selector
        self.ec_register_combo = QComboBox()
        for register, name in self.controller.ec_fan_registers.items():
            self.ec_register_combo.addItem(f"{name} (0x{register})", register)
        individual_layout.addWidget(QLabel("Fan:"))
        individual_layout.addWidget(self.ec_register_combo)
        
        # PWM input
        self.ec_pwm_spin = QSpinBox()
        self.ec_pwm_spin.setRange(0, 255)
        self.ec_pwm_spin.setValue(128)
        individual_layout.addWidget(QLabel("PWM:"))
        individual_layout.addWidget(self.ec_pwm_spin)
        
        # Set button
        set_btn = QPushButton("Set Fan")
        set_btn.clicked.connect(self.set_individual_ec_fan)
        individual_layout.addWidget(set_btn)
        
        layout.addWidget(individual_group)
        
        return widget
    
    def set_all_ec_fans(self, pwm_value: int):
        """Set all EC fans to the same PWM value"""
        for register in self.controller.ec_fan_registers.keys():
            self.controller.set_ec_fan_pwm(register, pwm_value)
            if register in self.ec_widgets:
                self.ec_widgets[register].set_pwm(pwm_value)
        
        self.log_message(f"Set all EC fans to PWM {pwm_value}")
    
    def set_individual_ec_fan(self):
        """Set individual EC fan"""
        register = self.ec_register_combo.currentData()
        pwm_value = self.ec_pwm_spin.value()
        
        if self.controller.set_ec_fan_pwm(register, pwm_value):
            if register in self.ec_widgets:
                self.ec_widgets[register].set_pwm(pwm_value)
            self.log_message(f"Set EC fan {register} to PWM {pwm_value}")
        else:
            self.log_message(f"Failed to set EC fan {register}")
    
    def create_monitoring_tab(self):
        """Create the monitoring tab"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Title
        title = QLabel("📊 Real-time Monitoring")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # Monitoring groups
        monitor_layout = QHBoxLayout()
        
        # hwmon6 fans (read-only)
        hwmon6_group = QGroupBox("hwmon6 Fans (Read-only)")
        hwmon6_layout = QVBoxLayout(hwmon6_group)
        
        self.hwmon6_labels = {}
        
        for i in range(1, 5):
            fan_layout = QHBoxLayout()
            
            label = QLabel(f"Fan {i}: ")
            rpm_label = QLabel("0 RPM")
            rpm_label.setStyleSheet("font-weight: bold; color: blue;")
            
            fan_layout.addWidget(label)
            fan_layout.addWidget(rpm_label)
            fan_layout.addStretch()
            
            self.hwmon6_labels[f'fan{i}'] = rpm_label
            hwmon6_layout.addLayout(fan_layout)
        
        monitor_layout.addWidget(hwmon6_group)
        
        # Temperature monitoring
        temp_group = QGroupBox("Temperatures")
        temp_layout = QVBoxLayout(temp_group)
        
        self.temp_labels = {}
        
        for i in range(8):
            temp_layout_item = QHBoxLayout()
            
            label = QLabel(f"Zone {i}: ")
            temp_label = QLabel("0°C")
            temp_label.setStyleSheet("font-weight: bold; color: red;")
            
            temp_layout_item.addWidget(label)
            temp_layout_item.addWidget(temp_label)
            temp_layout_item.addStretch()
            
            self.temp_labels[f'zone{i}'] = temp_label
            temp_layout.addLayout(temp_layout_item)
        
        monitor_layout.addWidget(temp_group)
        
        layout.addLayout(monitor_layout)
        
        # Update timestamp
        self.timestamp_label = QLabel("Last update: Never")
        self.timestamp_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.timestamp_label)
        
        return widget
    
    def create_presets_tab(self):
        """Create the presets tab"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Title
        title = QLabel("⚙️ Fan Presets")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # Preset buttons
        presets = [
            ("Silent Mode", "silent", "12.5% PWM - Quiet operation"),
            ("Quiet Mode", "quiet", "25% PWM - Low noise"),
            ("Normal Mode", "normal", "50% PWM - Balanced"),
            ("Performance Mode", "performance", "75% PWM - High performance"),
            ("Maximum Mode", "max", "100% PWM - Maximum cooling"),
            ("Gaming Mode", "gaming", "78% PWM - Gaming optimized"),
            ("Stress Test Mode", "stress", "94% PWM - Maximum cooling")
        ]
        
        for name, mode, description in presets:
            preset_layout = QHBoxLayout()
            
            btn = QPushButton(name)
            btn.setMinimumHeight(50)
            btn.clicked.connect(lambda checked, m=mode: self.set_preset_mode(m))
            preset_layout.addWidget(btn)
            
            desc_label = QLabel(description)
            desc_label.setStyleSheet("color: gray;")
            preset_layout.addWidget(desc_label)
            
            layout.addLayout(preset_layout)
        
        # Temperature-based control
        temp_group = QGroupBox("Temperature-Based Control")
        temp_layout = QVBoxLayout(temp_group)
        
        temp_control_layout = QHBoxLayout()
        
        temp_control_layout.addWidget(QLabel("Target Temp (°C):"))
        self.target_temp_spin = QSpinBox()
        self.target_temp_spin.setRange(50, 100)
        self.target_temp_spin.setValue(80)
        temp_control_layout.addWidget(self.target_temp_spin)
        
        temp_control_layout.addWidget(QLabel("Max PWM:"))
        self.max_pwm_spin = QSpinBox()
        self.max_pwm_spin.setRange(64, 255)
        self.max_pwm_spin.setValue(255)
        temp_control_layout.addWidget(self.max_pwm_spin)
        
        self.temp_control_btn = QPushButton("Start Temp Control")
        self.temp_control_btn.setCheckable(True)
        self.temp_control_btn.clicked.connect(self.toggle_temp_control)
        temp_control_layout.addWidget(self.temp_control_btn)
        
        temp_layout.addLayout(temp_control_layout)
        layout.addWidget(temp_group)
        
        # Restore BIOS control
        restore_btn = QPushButton("🔄 Restore BIOS Control")
        restore_btn.setStyleSheet("background-color: orange; color: white; font-weight: bold;")
        restore_btn.clicked.connect(self.restore_bios_control)
        layout.addWidget(restore_btn)
        
        layout.addStretch()
        return widget
    
    def create_system_tab(self):
        """Create the system info tab"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Title
        title = QLabel("💻 System Information")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # System info text
        self.system_text = QTextEdit()
        self.system_text.setReadOnly(True)
        layout.addWidget(self.system_text)
        
        # Refresh button
        refresh_btn = QPushButton("Refresh System Info")
        refresh_btn.clicked.connect(self.update_system_info)
        layout.addWidget(refresh_btn)
        
        # Initial update
        self.update_system_info()
        
        return widget
    
    def set_preset_mode(self, mode):
        """Set preset mode"""
        if self.controller.apply_preset(mode):
            self.log_message(f"Applied {mode} preset")
        else:
            self.log_message(f"Failed to apply {mode} preset")
    
    def toggle_temp_control(self):
        """Toggle temperature-based control"""
        if self.temp_control_btn.isChecked():
            target_temp = self.target_temp_spin.value()
            max_pwm = self.max_pwm_spin.value()
            
            # Start temperature control thread
            self.temp_control_thread = FanControlThread("temp", [str(target_temp), str(max_pwm)])
            self.temp_control_thread.update_signal.connect(self.log_message)
            self.temp_control_thread.start()
            
            self.temp_control_btn.setText("Stop Temp Control")
        else:
            # Stop temperature control (restore BIOS control)
            self.restore_bios_control()
            self.temp_control_btn.setText("Start Temp Control")
    
    def restore_bios_control(self):
        """Restore BIOS fan control"""
        thread = FanControlThread("restore")
        thread.update_signal.connect(self.log_message)
        thread.start()
    
    def update_system_info(self):
        """Update system information"""
        try:
            info = self.controller.get_system_info()
            
            info_text = "System Information:\n\n"
            
            if 'kernel' in info:
                info_text += f"Kernel: {info['kernel']}\n"
            if 'cpu' in info:
                info_text += f"CPU: {info['cpu']}\n"
            if 'memory' in info:
                info_text += f"Memory: {info['memory']}\n"
            if 'gpu' in info:
                info_text += f"GPU: {info['gpu']}\n"
            
            if 'fan_control' in info:
                fc = info['fan_control']
                info_text += f"\nFan Control Status:\n"
                info_text += f"- hwmon fans: {fc['hwmon_fans']}\n"
                info_text += f"- EC fans: {fc['ec_fans']}\n"
                info_text += f"- Total controllable: {fc['total_controllable']}\n"
            
            self.system_text.setText(info_text)
            
        except Exception as e:
            self.system_text.setText(f"Error getting system info: {e}")
    
    def setup_devices(self):
        """Setup device widgets"""
        # This will be called from create_fan_control_tab
        pass
    
    def setup_monitoring(self):
        """Setup monitoring"""
        # Start monitoring thread
        self.monitor = SensorMonitor(self.controller)
        self.monitor.data_updated.connect(self.on_sensor_data)
        self.monitor.error_occurred.connect(self.on_monitor_error)
        self.monitor.start()
    
    def setup_system_tray(self):
        """Setup system tray icon"""
        self.tray_icon = QSystemTrayIcon(self)
        
        # Create tray menu
        tray_menu = QMenu()
        
        show_action = tray_menu.addAction("Show")
        show_action.triggered.connect(self.show)
        
        quit_action = tray_menu.addAction("Quit")
        quit_action.triggered.connect(self.close)
        
        self.tray_icon.setContextMenu(tray_menu)
        self.tray_icon.show()
    
    def on_sensor_data(self, speeds, temps, pwms):
        """Handle sensor data updates"""
        # Update fan speeds and temperatures
        # This will be implemented based on the existing monitoring system
        pass
    
    def on_monitor_error(self, error):
        """Handle monitoring errors"""
        self.log_message(f"Monitor error: {error}")
    
    def log_message(self, message):
        """Add message to log"""
        timestamp = datetime.now().strftime('%H:%M:%S')
        # Log to status bar
        self.statusBar().showMessage(f"[{timestamp}] {message}", 5000)
    
    def closeEvent(self, event):
        """Handle application close"""
        if hasattr(self, 'monitor') and self.monitor:
            self.monitor.stop()
            self.monitor.wait()
        event.accept()

def main():
    # Check if running as root
    if os.geteuid() != 0:
        print("Warning: This application may need root privileges for fan control")
        print("Run with: sudo python3 alienfan_gui_enhanced.py")
        
    app = QApplication(sys.argv)
    
    # Set application style
    app.setStyle('Fusion')
    
    # Create and show the main window
    window = AlienwareFanGUI()
    window.show()
    
    sys.exit(app.exec_())

if __name__ == "__main__":
    main() 