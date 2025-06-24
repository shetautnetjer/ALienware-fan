#!/usr/bin/env python3
"""
🔥 Alienware Fan Control GUI - Tkinter Version
Fallback GUI using Tkinter (usually available by default)
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import json
import os
import time
import threading
from datetime import datetime
from typing import Dict, List, Optional

class FanController:
    """Backend controller for fan operations"""
    
    def __init__(self):
        self.hwmon_paths = self._discover_hwmon_devices()
        self.fan_devices = self._discover_fan_devices()
        self.temp_devices = self._discover_temp_devices()
        self.config = self._load_config()
        
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
    
    def apply_preset(self, preset_name: str) -> bool:
        """Apply a preset configuration"""
        if 'presets' not in self.config:
            return False
            
        if preset_name not in self.config['presets']:
            return False
            
        preset = self.config['presets'][preset_name]
        pwm_value = preset.get('pwm_value', 128)
        return self.set_all_pwm(pwm_value)

class FanControlFrame(ttk.LabelFrame):
    """Frame for controlling individual fans"""
    
    def __init__(self, parent, hwmon_name: str, fan_num: str, device_name: str, controller: FanController):
        super().__init__(parent, text=f"{device_name} - Fan {fan_num}")
        self.hwmon_name = hwmon_name
        self.fan_num = fan_num
        self.device_name = device_name
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        # RPM display
        self.rpm_label = ttk.Label(self, text="RPM: --", font=("Arial", 12, "bold"))
        self.rpm_label.grid(row=0, column=0, columnspan=2, pady=5)
        
        # Control mode
        ttk.Label(self, text="Mode:").grid(row=1, column=0, sticky="w", padx=5)
        self.mode_var = tk.StringVar(value="Auto")
        self.mode_combo = ttk.Combobox(self, textvariable=self.mode_var, 
                                      values=["Auto", "Manual", "Full Speed"], 
                                      state="readonly", width=10)
        self.mode_combo.grid(row=1, column=1, padx=5, pady=2)
        self.mode_combo.bind("<<ComboboxSelected>>", self.on_mode_changed)
        
        # PWM slider
        ttk.Label(self, text="PWM:").grid(row=2, column=0, sticky="w", padx=5)
        self.pwm_var = tk.IntVar(value=128)
        self.pwm_slider = ttk.Scale(self, from_=0, to=255, variable=self.pwm_var, 
                                   orient="horizontal", length=150)
        self.pwm_slider.grid(row=2, column=1, padx=5, pady=2)
        self.pwm_slider.bind("<ButtonRelease-1>", self.on_pwm_changed)
        
        # PWM value label
        self.pwm_label = ttk.Label(self, text="128")
        self.pwm_label.grid(row=3, column=1, pady=2)
        
        # Status label
        self.status_label = ttk.Label(self, text="Ready", foreground="green")
        self.status_label.grid(row=4, column=0, columnspan=2, pady=5)
        
    def update_rpm(self, rpm: int):
        self.rpm_label.config(text=f"RPM: {rpm:,}")
        
    def update_pwm(self, pwm: int):
        self.pwm_var.set(pwm)
        self.pwm_label.config(text=str(pwm))
        
    def on_mode_changed(self, event=None):
        mode = self.mode_var.get()
        if mode == "Auto":
            self.status_label.config(text="Auto Mode", foreground="blue")
        elif mode == "Manual":
            pwm_value = self.pwm_var.get()
            if self.controller.set_pwm(self.hwmon_name, self.fan_num, pwm_value):
                self.status_label.config(text="Manual Mode", foreground="green")
            else:
                self.status_label.config(text="Error", foreground="red")
        elif mode == "Full Speed":
            if self.controller.set_pwm(self.hwmon_name, self.fan_num, 255):
                self.status_label.config(text="Full Speed", foreground="red")
            else:
                self.status_label.config(text="Error", foreground="red")
                
    def on_pwm_changed(self, event=None):
        value = self.pwm_var.get()
        self.pwm_label.config(text=str(value))
        if self.mode_var.get() == "Manual":
            if self.controller.set_pwm(self.hwmon_name, self.fan_num, value):
                self.status_label.config(text="Manual Mode", foreground="green")
            else:
                self.status_label.config(text="Error", foreground="red")

class TemperatureFrame(ttk.LabelFrame):
    """Frame for displaying temperature sensors"""
    
    def __init__(self, parent, hwmon_name: str, temp_num: str, device_name: str, controller: FanController):
        super().__init__(parent, text=f"{device_name} - Temp {temp_num}")
        self.hwmon_name = hwmon_name
        self.temp_num = temp_num
        self.device_name = device_name
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        # Temperature display
        self.temp_label = ttk.Label(self, text="--°C", font=("Arial", 14, "bold"))
        self.temp_label.grid(row=0, column=0, pady=5)
        
        # Progress bar
        self.temp_bar = ttk.Progressbar(self, length=100, mode='determinate')
        self.temp_bar.grid(row=1, column=0, pady=2)
        
        # Status label
        self.status_label = ttk.Label(self, text="Normal", foreground="green")
        self.status_label.grid(row=2, column=0, pady=5)
        
    def update_temperature(self, temp: float):
        self.temp_label.config(text=f"{temp:.1f}°C")
        self.temp_bar['value'] = min(temp, 100)
        
        # Color coding based on temperature
        if temp < 50:
            color = "green"
            status = "Cool"
        elif temp < 70:
            color = "orange"
            status = "Warm"
        elif temp < 85:
            color = "red"
            status = "Hot"
        else:
            color = "purple"
            status = "Critical"
            
        self.temp_label.config(foreground=color)
        self.status_label.config(text=status, foreground=color)

class PresetFrame(ttk.LabelFrame):
    """Frame for managing fan presets"""
    
    def __init__(self, parent, controller: FanController):
        super().__init__(parent, text="Quick Presets")
        self.controller = controller
        self.setup_ui()
        
    def setup_ui(self):
        # Preset buttons
        presets = [
            ("Quiet Mode", "quiet"),
            ("Balanced", "balanced"),
            ("Performance", "performance"),
            ("Max Cooling", "max"),
            ("Gaming", "gaming"),
            ("Stress Test", "stress")
        ]
        
        for i, (name, preset_id) in enumerate(presets):
            btn = ttk.Button(self, text=name, 
                           command=lambda pid=preset_id: self.apply_preset(pid))
            btn.grid(row=i//3, column=i%3, padx=5, pady=2, sticky="ew")
        
        # Custom PWM control
        ttk.Separator(self, orient="horizontal").grid(row=2, column=0, columnspan=3, 
                                                     sticky="ew", pady=10)
        
        ttk.Label(self, text="Custom PWM:").grid(row=3, column=0, sticky="w", padx=5)
        self.custom_pwm_var = tk.IntVar(value=128)
        self.custom_slider = ttk.Scale(self, from_=0, to=255, variable=self.custom_pwm_var,
                                      orient="horizontal", length=150)
        self.custom_slider.grid(row=3, column=1, columnspan=2, padx=5, pady=2)
        
        self.custom_label = ttk.Label(self, text="128")
        self.custom_label.grid(row=4, column=1, pady=2)
        
        apply_btn = ttk.Button(self, text="Apply to All Fans", 
                              command=self.apply_custom_pwm)
        apply_btn.grid(row=5, column=0, columnspan=3, pady=5)
        
        # Status label
        self.status_label = ttk.Label(self, text="Ready", foreground="green")
        self.status_label.grid(row=6, column=0, columnspan=3, pady=5)
        
        # Bind slider update
        self.custom_slider.bind("<ButtonRelease-1>", self.on_custom_pwm_changed)
        
    def apply_preset(self, preset: str):
        if self.controller.apply_preset(preset):
            self.status_label.config(text=f"Applied {preset} preset", foreground="green")
        else:
            self.status_label.config(text="Error applying preset", foreground="red")
            
    def on_custom_pwm_changed(self, event=None):
        value = self.custom_pwm_var.get()
        self.custom_label.config(text=str(value))
        
    def apply_custom_pwm(self):
        value = self.custom_pwm_var.get()
        if self.controller.set_all_pwm(value):
            self.status_label.config(text=f"Applied PWM {value} to all fans", foreground="green")
        else:
            self.status_label.config(text="Error applying PWM", foreground="red")

class AlienwareFanGUI:
    """Main GUI window for Alienware fan control using Tkinter"""
    
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("🔥 Alienware Fan Control - Tkinter")
        self.root.geometry("900x700")
        
        self.controller = FanController()
        self.fan_frames = {}
        self.temp_frames = {}
        self.running = True
        
        self.setup_ui()
        self.setup_monitoring()
        
    def setup_ui(self):
        # Main frame
        main_frame = ttk.Frame(self.root)
        main_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Status bar
        status_frame = ttk.Frame(main_frame)
        status_frame.pack(fill="x", pady=(0, 10))
        
        self.status_label = ttk.Label(status_frame, text="Ready", foreground="green")
        self.status_label.pack(side="left")
        
        refresh_btn = ttk.Button(status_frame, text="Refresh Devices", 
                                command=self.refresh_devices)
        refresh_btn.pack(side="right")
        
        # Notebook for tabs
        self.notebook = ttk.Notebook(main_frame)
        self.notebook.pack(fill="both", expand=True)
        
        # Dashboard tab
        dashboard_frame = ttk.Frame(self.notebook)
        self.notebook.add(dashboard_frame, text="Dashboard")
        
        # Temperature section
        temp_frame = ttk.LabelFrame(dashboard_frame, text="Temperature Sensors")
        temp_frame.pack(fill="x", padx=5, pady=5)
        
        self.temp_container = ttk.Frame(temp_frame)
        self.temp_container.pack(fill="x", padx=5, pady=5)
        
        # Fan control section
        fan_frame = ttk.LabelFrame(dashboard_frame, text="Fan Control")
        fan_frame.pack(fill="both", expand=True, padx=5, pady=5)
        
        self.fan_container = ttk.Frame(fan_frame)
        self.fan_container.pack(fill="both", expand=True, padx=5, pady=5)
        
        # Presets tab
        presets_frame = ttk.Frame(self.notebook)
        self.notebook.add(presets_frame, text="Presets")
        
        self.preset_widget = PresetFrame(presets_frame, self.controller)
        self.preset_widget.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Log tab
        log_frame = ttk.Frame(self.notebook)
        self.notebook.add(log_frame, text="Log")
        
        self.log_text = scrolledtext.ScrolledText(log_frame, height=20)
        self.log_text.pack(fill="both", expand=True, padx=5, pady=5)
        
        # Setup devices
        self.setup_devices()
        
    def setup_devices(self):
        # Clear existing frames
        for frame in self.fan_frames.values():
            frame.destroy()
        for frame in self.temp_frames.values():
            frame.destroy()
            
        self.fan_frames.clear()
        self.temp_frames.clear()
        
        # Setup temperature frames
        row = 0
        col = 0
        for hwmon_name, device_info in self.controller.temp_devices.items():
            for temp_num in device_info['temp_inputs']:
                frame = TemperatureFrame(self.temp_container, hwmon_name, temp_num, 
                                       device_info['name'], self.controller)
                frame.grid(row=row, column=col, padx=5, pady=5, sticky="nsew")
                self.temp_frames[f"{hwmon_name}_{temp_num}"] = frame
                col += 1
                if col > 3:  # 4 columns
                    col = 0
                    row += 1
                    
        # Setup fan frames
        row = 0
        col = 0
        for hwmon_name, device_info in self.controller.fan_devices.items():
            for fan_num in device_info['fan_inputs']:
                frame = FanControlFrame(self.fan_container, hwmon_name, fan_num, 
                                      device_info['name'], self.controller)
                frame.grid(row=row, column=col, padx=5, pady=5, sticky="nsew")
                self.fan_frames[f"{hwmon_name}_{fan_num}"] = frame
                col += 1
                if col > 2:  # 3 columns for fan controls
                    col = 0
                    row += 1
                    
        self.log_message(f"Discovered {len(self.controller.temp_devices)} temp devices, {len(self.controller.fan_devices)} fan devices")
        
    def setup_monitoring(self):
        """Start monitoring thread"""
        self.monitor_thread = threading.Thread(target=self.monitor_sensors, daemon=True)
        self.monitor_thread.start()
        
    def monitor_sensors(self):
        """Monitor sensors in background thread"""
        while self.running:
            try:
                speeds = self.controller.get_fan_speeds()
                temps = self.controller.get_temperatures()
                pwms = self.controller.get_pwm_values()
                
                # Update UI in main thread
                self.root.after(0, self.update_sensor_data, speeds, temps, pwms)
                
            except Exception as e:
                self.root.after(0, self.log_message, f"Monitor error: {e}")
                
            time.sleep(2)  # Update every 2 seconds
            
    def update_sensor_data(self, speeds: Dict, temps: Dict, pwms: Dict):
        """Update sensor data in UI"""
        # Update fan speeds
        for hwmon_name, fan_speeds in speeds.items():
            for fan_num, speed in fan_speeds.items():
                frame_key = f"{hwmon_name}_{fan_num}"
                if frame_key in self.fan_frames:
                    self.fan_frames[frame_key].update_rpm(speed)
                    
        # Update temperatures
        for hwmon_name, temp_sensors in temps.items():
            for temp_num, temp in temp_sensors.items():
                frame_key = f"{hwmon_name}_{temp_num}"
                if frame_key in self.temp_frames:
                    self.temp_frames[frame_key].update_temperature(temp)
                    
        # Update PWM values
        for hwmon_name, fan_pwms in pwms.items():
            for fan_num, pwm in fan_pwms.items():
                frame_key = f"{hwmon_name}_{fan_num}"
                if frame_key in self.fan_frames:
                    self.fan_frames[frame_key].update_pwm(pwm)
                    
    def refresh_devices(self):
        """Refresh device discovery"""
        self.controller = FanController()
        self.setup_devices()
        self.log_message("Devices refreshed")
        self.status_label.config(text="Devices refreshed", foreground="green")
        
    def log_message(self, message: str):
        """Add message to log"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.log_text.insert("end", f"[{timestamp}] {message}\n")
        self.log_text.see("end")
        
    def run(self):
        """Start the GUI"""
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        self.root.mainloop()
        
    def on_closing(self):
        """Handle window closing"""
        self.running = False
        self.root.destroy()

def main():
    # Check if running as root
    if os.geteuid() != 0:
        print("Warning: This application may need root privileges for fan control")
        print("Run with: sudo python3 alienfan_gui_tkinter.py")
        
    app = AlienwareFanGUI()
    app.run()

if __name__ == "__main__":
    main() 