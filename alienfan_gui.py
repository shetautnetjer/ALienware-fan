#!/usr/bin/env python3
"""
🔥 Alienware Fan Control GUI
Production-grade GUI for monitoring and controlling Alienware laptop fans
"""

import sys
import os
import json
import time
import threading
from datetime import datetime
from typing import Dict, List, Optional, Tuple

try:
    from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                                QHBoxLayout, QGridLayout, QLabel, QComboBox, 
                                QSlider, QPushButton, QGroupBox, QTabWidget,
                                QProgressBar, QCheckBox, QSpinBox, QTextEdit,
                                QMessageBox, QFileDialog, QSystemTrayIcon,
                                QMenu, QAction, QFrame, QSplitter)
    from PyQt5.QtCore import QTimer, QThread, pyqtSignal, Qt, QSettings
    from PyQt5.QtGui import QFont, QIcon, QPalette, QColor, QPixmap
    PYQT_AVAILABLE = True
except ImportError:
    print("PyQt5 not available, falling back to Tkinter...")
    PYQT_AVAILABLE = False
    import tkinter as tk
    from tkinter import ttk, messagebox

class FanController:
    """Backend controller for fan operations"""
    
    def __init__(self):
        self.hwmon_paths = self._discover_hwmon_devices()
        self.fan_devices = self._discover_fan_devices()
        self.temp_devices = self._discover_temp_devices()
        
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
    
    def set_all_pwm(self, pwm_value: int) -> bool:
        """Set PWM value for all controllable fans"""
        success = True
        for hwmon_name, device_info in self.fan_devices.items():
            for fan_num in device_info['fan_pwms']:
                if not self.set_pwm(hwmon_name, fan_num, pwm_value):
                    success = False
        return success

class SensorMonitor(QThread):
    """Thread for monitoring sensors"""
    data_updated = pyqtSignal(dict, dict, dict)  # speeds, temps, pwms
    
    def __init__(self, controller: FanController):
        super().__init__()
        self.controller = controller
        self.running = True
        
    def run(self):
        while self.running:
            try:
                speeds = self.controller.get_fan_speeds()
                temps = self.controller.get_temperatures()
                pwms = self.controller.get_pwm_values()
                self.data_updated.emit(speeds, temps, pwms)
            except Exception as e:
                print(f"Error reading sensors: {e}")
            
            time.sleep(2)  # Update every 2 seconds
    
    def stop(self):
        self.running = False

class FanControlWidget(QWidget):
    """Widget for controlling individual fans"""
    
    def __init__(self, hwmon_name: str, fan_num: str, device_name: str, controller: FanController):
        super().__init__()
        self.hwmon_name = hwmon_name
        self.fan_num = fan_num
        self.device_name = device_name
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Fan label
        fan_label = QLabel(f"{self.device_name} - Fan {self.fan_num}")
        fan_label.setFont(QFont("Arial", 10, QFont.Bold))
        layout.addWidget(fan_label)
        
        # RPM display
        self.rpm_label = QLabel("RPM: --")
        self.rpm_label.setFont(QFont("Arial", 12))
        layout.addWidget(self.rpm_label)
        
        # Control mode
        mode_layout = QHBoxLayout()
        mode_layout.addWidget(QLabel("Mode:"))
        
        self.mode_combo = QComboBox()
        self.mode_combo.addItems(["Auto", "Manual", "Full Speed"])
        self.mode_combo.currentTextChanged.connect(self.on_mode_changed)
        mode_layout.addWidget(self.mode_combo)
        
        layout.addLayout(mode_layout)
        
        # PWM slider
        pwm_layout = QHBoxLayout()
        pwm_layout.addWidget(QLabel("PWM:"))
        
        self.pwm_slider = QSlider(Qt.Horizontal)
        self.pwm_slider.setRange(0, 255)
        self.pwm_slider.setValue(128)
        self.pwm_slider.valueChanged.connect(self.on_pwm_changed)
        pwm_layout.addWidget(self.pwm_slider)
        
        self.pwm_label = QLabel("128")
        pwm_layout.addWidget(self.pwm_label)
        
        layout.addLayout(pwm_layout)
        
        # PWM progress bar
        self.pwm_bar = QProgressBar()
        self.pwm_bar.setRange(0, 255)
        self.pwm_bar.setValue(128)
        layout.addWidget(self.pwm_bar)
        
        self.setLayout(layout)
        
    def update_rpm(self, rpm: int):
        self.rpm_label.setText(f"RPM: {rpm}")
        
    def update_pwm(self, pwm: int):
        self.pwm_slider.setValue(pwm)
        self.pwm_label.setText(str(pwm))
        self.pwm_bar.setValue(pwm)
        
    def on_mode_changed(self, mode: str):
        if mode == "Auto":
            # Let BIOS handle it
            pass
        elif mode == "Manual":
            pwm_value = self.pwm_slider.value()
            self.controller.set_pwm(self.hwmon_name, self.fan_num, pwm_value)
        elif mode == "Full Speed":
            self.controller.set_pwm(self.hwmon_name, self.fan_num, 255)
            
    def on_pwm_changed(self, value: int):
        self.pwm_label.setText(str(value))
        self.pwm_bar.setValue(value)
        if self.mode_combo.currentText() == "Manual":
            self.controller.set_pwm(self.hwmon_name, self.fan_num, value)

class TemperatureWidget(QWidget):
    """Widget for displaying temperature sensors"""
    
    def __init__(self, hwmon_name: str, temp_num: str, device_name: str):
        super().__init__()
        self.hwmon_name = hwmon_name
        self.temp_num = temp_num
        self.device_name = device_name
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Temperature label
        temp_label = QLabel(f"{self.device_name} - Temp {self.temp_num}")
        temp_label.setFont(QFont("Arial", 10, QFont.Bold))
        layout.addWidget(temp_label)
        
        # Temperature display
        self.temp_label = QLabel("--°C")
        self.temp_label.setFont(QFont("Arial", 16, QFont.Bold))
        layout.addWidget(self.temp_label)
        
        # Temperature progress bar
        self.temp_bar = QProgressBar()
        self.temp_bar.setRange(0, 100)
        self.temp_bar.setValue(0)
        layout.addWidget(self.temp_bar)
        
        self.setLayout(layout)
        
    def update_temperature(self, temp: float):
        self.temp_label.setText(f"{temp:.1f}°C")
        self.temp_bar.setValue(int(temp))
        
        # Color coding based on temperature
        if temp < 50:
            color = "green"
        elif temp < 70:
            color = "orange"
        elif temp < 85:
            color = "red"
        else:
            color = "purple"
            
        self.temp_label.setStyleSheet(f"color: {color};")

class PresetWidget(QWidget):
    """Widget for managing fan presets"""
    
    def __init__(self, controller: FanController):
        super().__init__()
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Preset buttons
        preset_group = QGroupBox("Quick Presets")
        preset_layout = QGridLayout()
        
        # Quiet mode
        quiet_btn = QPushButton("Quiet Mode")
        quiet_btn.clicked.connect(lambda: self.apply_preset("quiet"))
        preset_layout.addWidget(quiet_btn, 0, 0)
        
        # Balanced mode
        balanced_btn = QPushButton("Balanced")
        balanced_btn.clicked.connect(lambda: self.apply_preset("balanced"))
        preset_layout.addWidget(balanced_btn, 0, 1)
        
        # Performance mode
        perf_btn = QPushButton("Performance")
        perf_btn.clicked.connect(lambda: self.apply_preset("performance"))
        preset_layout.addWidget(perf_btn, 1, 0)
        
        # Max cooling
        max_btn = QPushButton("Max Cooling")
        max_btn.clicked.connect(lambda: self.apply_preset("max"))
        preset_layout.addWidget(max_btn, 1, 1)
        
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
        pwm_layout.addWidget(self.custom_pwm_slider)
        
        self.custom_pwm_label = QLabel("128")
        pwm_layout.addWidget(self.custom_pwm_label)
        
        custom_layout.addLayout(pwm_layout)
        
        apply_btn = QPushButton("Apply to All Fans")
        apply_btn.clicked.connect(self.apply_custom_pwm)
        custom_layout.addWidget(apply_btn)
        
        custom_group.setLayout(custom_layout)
        layout.addWidget(custom_group)
        
        self.setLayout(layout)
        
    def apply_preset(self, preset: str):
        pwm_values = {
            "quiet": 64,
            "balanced": 128,
            "performance": 192,
            "max": 255
        }
        
        if preset in pwm_values:
            self.controller.set_all_pwm(pwm_values[preset])
            
    def on_custom_pwm_changed(self, value: int):
        self.custom_pwm_label.setText(str(value))
        
    def apply_custom_pwm(self):
        value = self.custom_pwm_slider.value()
        self.controller.set_all_pwm(value)

class AlienwareFanGUI(QMainWindow):
    """Main GUI window for Alienware fan control"""
    
    def __init__(self):
        super().__init__()
        self.controller = FanController()
        self.fan_widgets = {}
        self.temp_widgets = {}
        self.setup_ui()
        self.setup_monitoring()
        
    def setup_ui(self):
        self.setWindowTitle("🔥 Alienware Fan Control")
        self.setGeometry(100, 100, 800, 600)
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Main layout
        main_layout = QVBoxLayout()
        
        # Status bar
        status_layout = QHBoxLayout()
        self.status_label = QLabel("Ready")
        status_layout.addWidget(self.status_label)
        
        # Refresh button
        refresh_btn = QPushButton("Refresh")
        refresh_btn.clicked.connect(self.refresh_devices)
        status_layout.addWidget(refresh_btn)
        
        main_layout.addLayout(status_layout)
        
        # Tab widget
        self.tab_widget = QTabWidget()
        
        # Dashboard tab
        dashboard_tab = QWidget()
        dashboard_layout = QVBoxLayout()
        
        # Temperature section
        temp_group = QGroupBox("Temperature Sensors")
        self.temp_layout = QGridLayout()
        temp_group.setLayout(self.temp_layout)
        dashboard_layout.addWidget(temp_group)
        
        # Fan control section
        fan_group = QGroupBox("Fan Control")
        self.fan_layout = QGridLayout()
        fan_group.setLayout(self.fan_layout)
        dashboard_layout.addWidget(fan_group)
        
        dashboard_tab.setLayout(dashboard_layout)
        self.tab_widget.addTab(dashboard_tab, "Dashboard")
        
        # Presets tab
        presets_tab = PresetWidget(self.controller)
        self.tab_widget.addTab(presets_tab, "Presets")
        
        # Log tab
        log_tab = QWidget()
        log_layout = QVBoxLayout()
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        log_layout.addWidget(self.log_text)
        log_tab.setLayout(log_layout)
        self.tab_widget.addTab(log_tab, "Log")
        
        main_layout.addWidget(self.tab_widget)
        
        central_widget.setLayout(main_layout)
        
        # Setup devices
        self.setup_devices()
        
    def setup_devices(self):
        # Clear existing widgets
        for widget in self.fan_widgets.values():
            widget.setParent(None)
        for widget in self.temp_widgets.values():
            widget.setParent(None)
            
        self.fan_widgets.clear()
        self.temp_widgets.clear()
        
        # Setup temperature widgets
        row = 0
        col = 0
        for hwmon_name, device_info in self.controller.temp_devices.items():
            for temp_num in device_info['temp_inputs']:
                widget = TemperatureWidget(hwmon_name, temp_num, device_info['name'])
                self.temp_widgets[f"{hwmon_name}_{temp_num}"] = widget
                self.temp_layout.addWidget(widget, row, col)
                col += 1
                if col > 2:  # 3 columns
                    col = 0
                    row += 1
                    
        # Setup fan widgets
        row = 0
        col = 0
        for hwmon_name, device_info in self.controller.fan_devices.items():
            for fan_num in device_info['fan_inputs']:
                widget = FanControlWidget(hwmon_name, fan_num, device_info['name'], self.controller)
                self.fan_widgets[f"{hwmon_name}_{fan_num}"] = widget
                self.fan_layout.addWidget(widget, row, col)
                col += 1
                if col > 1:  # 2 columns for fan controls
                    col = 0
                    row += 1
                    
        self.log_message(f"Discovered {len(self.controller.temp_devices)} temp devices, {len(self.controller.fan_devices)} fan devices")
        
    def setup_monitoring(self):
        self.monitor = SensorMonitor(self.controller)
        self.monitor.data_updated.connect(self.on_sensor_data)
        self.monitor.start()
        
    def on_sensor_data(self, speeds: Dict, temps: Dict, pwms: Dict):
        # Update fan speeds
        for hwmon_name, fan_speeds in speeds.items():
            for fan_num, speed in fan_speeds.items():
                widget_key = f"{hwmon_name}_{fan_num}"
                if widget_key in self.fan_widgets:
                    self.fan_widgets[widget_key].update_rpm(speed)
                    
        # Update temperatures
        for hwmon_name, temp_sensors in temps.items():
            for temp_num, temp in temp_sensors.items():
                widget_key = f"{hwmon_name}_{temp_num}"
                if widget_key in self.temp_widgets:
                    self.temp_widgets[widget_key].update_temperature(temp)
                    
        # Update PWM values
        for hwmon_name, fan_pwms in pwms.items():
            for fan_num, pwm in fan_pwms.items():
                widget_key = f"{hwmon_name}_{fan_num}"
                if widget_key in self.fan_widgets:
                    self.fan_widgets[widget_key].update_pwm(pwm)
                    
    def refresh_devices(self):
        self.controller = FanController()
        self.setup_devices()
        self.log_message("Devices refreshed")
        
    def log_message(self, message: str):
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.log_text.append(f"[{timestamp}] {message}")
        
    def closeEvent(self, event):
        if hasattr(self, 'monitor'):
            self.monitor.stop()
            self.monitor.wait()
        event.accept()

def main():
    # Check if running as root
    if os.geteuid() != 0:
        print("Warning: This application may need root privileges for fan control")
        print("Run with: sudo python3 alienfan_gui.py")
        
    app = QApplication(sys.argv)
    
    # Set application style
    app.setStyle('Fusion')
    
    # Create and show the main window
    window = AlienwareFanGUI()
    window.show()
    
    sys.exit(app.exec_())

if __name__ == "__main__":
    main() 