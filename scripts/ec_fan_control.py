#!/usr/bin/env python3
"""
🔥 Alienware EC Fan Control
Direct EC access for fan control on Alienware laptops
"""

import os
import time
import struct
import fcntl
import mmap
from typing import Dict, List, Optional

class ECAccess:
    """Direct EC access for fan control"""
    
    def __init__(self):
        self.port_file = None
        self.ec_ports = {
            'command': 0x62,
            'data': 0x63,
            'smm_command': 0x66,
            'smm_data': 0x67
        }
        
    def open_port(self):
        """Open /dev/port for EC access"""
        try:
            self.port_file = os.open('/dev/port', os.O_RDWR)
            return True
        except:
            print("❌ Cannot open /dev/port (requires root)")
            return False
    
    def close_port(self):
        """Close port file"""
        if self.port_file:
            os.close(self.port_file)
            self.port_file = None
    
    def read_port(self, port: int) -> Optional[int]:
        """Read a byte from EC port"""
        if not self.port_file:
            return None
        
        try:
            os.lseek(self.port_file, port, 0)
            data = os.read(self.port_file, 1)
            return data[0] if data else None
        except:
            return None
    
    def write_port(self, port: int, value: int) -> bool:
        """Write a byte to EC port"""
        if not self.port_file:
            return False
        
        try:
            os.lseek(self.port_file, port, 0)
            os.write(self.port_file, bytes([value]))
            return True
        except:
            return False
    
    def ec_read(self, command: int) -> Optional[int]:
        """Read from EC using command protocol"""
        # Send command
        if not self.write_port(self.ec_ports['command'], command):
            return None
        
        # Wait for completion
        time.sleep(0.01)
        
        # Read data
        return self.read_port(self.ec_ports['data'])
    
    def ec_write(self, command: int, value: int) -> bool:
        """Write to EC using command protocol"""
        # Send command
        if not self.write_port(self.ec_ports['command'], command):
            return False
        
        # Wait for completion
        time.sleep(0.01)
        
        # Write data
        return self.write_port(self.ec_ports['data'], value)
    
    def smm_read(self, command: int) -> Optional[int]:
        """Read from EC using SMM protocol"""
        # Send SMM command
        if not self.write_port(self.ec_ports['smm_command'], command):
            return None
        
        # Wait for completion
        time.sleep(0.01)
        
        # Read data
        return self.read_port(self.ec_ports['smm_data'])
    
    def smm_write(self, command: int, value: int) -> bool:
        """Write to EC using SMM protocol"""
        # Send SMM command
        if not self.write_port(self.ec_ports['smm_command'], command):
            return False
        
        # Wait for completion
        time.sleep(0.01)
        
        # Write data
        return self.write_port(self.ec_ports['smm_data'], value)

class AlienwareFanController:
    """Alienware-specific fan controller"""
    
    def __init__(self):
        self.ec = ECAccess()
        self.fan_commands = {
            'fan1': 0x30,  # CPU Fan
            'fan2': 0x31,  # GPU Fan
            'fan3': 0x32,  # VRM Fan
            'fan4': 0x33,  # Exhaust Fan
            'fan5': 0x34,  # Chassis Fan
            'fan6': 0x35,  # Memory Fan
        }
        
    def open_ec(self) -> bool:
        """Open EC access"""
        return self.ec.open_port()
    
    def close_ec(self):
        """Close EC access"""
        self.ec.close_port()
    
    def get_fan_speed(self, fan_id: str) -> Optional[int]:
        """Get fan speed from EC"""
        if fan_id not in self.fan_commands:
            return None
        
        command = self.fan_commands[fan_id]
        return self.ec.ec_read(command)
    
    def set_fan_speed(self, fan_id: str, pwm_value: int) -> bool:
        """Set fan speed via EC"""
        if fan_id not in self.fan_commands:
            return False
        
        # PWM value should be 0-255
        pwm_value = max(0, min(255, pwm_value))
        
        command = self.fan_commands[fan_id]
        return self.ec.ec_write(command, pwm_value)
    
    def scan_ec_registers(self) -> Dict[int, int]:
        """Scan EC registers for fan-related data"""
        registers = {}
        
        print("🔍 Scanning EC registers...")
        
        # Scan common EC register ranges
        for base in [0x00, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x90, 0xA0, 0xB0, 0xC0, 0xD0, 0xE0, 0xF0]:
            for offset in range(16):
                register = base + offset
                value = self.ec.read_port(register)
                if value is not None and value != 0:
                    registers[register] = value
                    print(f"  Register 0x{register:02X}: 0x{value:02X} ({value})")
        
        return registers
    
    def test_fan_control(self):
        """Test fan control functionality"""
        print("🧪 Testing fan control...")
        
        for fan_id in self.fan_commands.keys():
            print(f"\nTesting {fan_id}:")
            
            # Get current speed
            current_speed = self.get_fan_speed(fan_id)
            if current_speed is not None:
                print(f"  Current speed: {current_speed}")
                
                # Test setting different speeds
                for test_pwm in [64, 128, 192, 255]:
                    print(f"  Setting PWM {test_pwm}...")
                    if self.set_fan_speed(fan_id, test_pwm):
                        time.sleep(1)
                        new_speed = self.get_fan_speed(fan_id)
                        print(f"    New speed: {new_speed}")
                        
                        # Restore original
                        self.set_fan_speed(fan_id, current_speed)
                    else:
                        print(f"    Failed to set PWM {test_pwm}")
            else:
                print(f"  Could not read fan speed")

def main():
    """Main function"""
    print("🔥 Alienware EC Fan Control")
    print("===========================")
    
    # Check if running as root
    if os.geteuid() != 0:
        print("❌ This script requires root privileges")
        print("Run with: sudo python3 ec_fan_control.py")
        return
    
    controller = AlienwareFanController()
    
    if not controller.open_ec():
        print("❌ Failed to open EC access")
        return
    
    try:
        # Scan EC registers
        registers = controller.scan_ec_registers()
        print(f"\n📊 Found {len(registers)} non-zero registers")
        
        # Test fan control
        controller.test_fan_control()
        
        # Interactive mode
        print("\n🎮 Interactive Mode")
        print("==================")
        print("Commands:")
        print("  get <fan>     - Get fan speed")
        print("  set <fan> <pwm> - Set fan PWM (0-255)")
        print("  scan          - Scan EC registers")
        print("  quit          - Exit")
        
        while True:
            try:
                cmd = input("\nEC> ").strip().split()
                if not cmd:
                    continue
                
                if cmd[0] == 'quit':
                    break
                elif cmd[0] == 'get' and len(cmd) == 2:
                    fan_id = cmd[1]
                    speed = controller.get_fan_speed(fan_id)
                    if speed is not None:
                        print(f"{fan_id} speed: {speed}")
                    else:
                        print(f"Could not read {fan_id} speed")
                elif cmd[0] == 'set' and len(cmd) == 3:
                    fan_id = cmd[1]
                    try:
                        pwm = int(cmd[2])
                        if controller.set_fan_speed(fan_id, pwm):
                            print(f"Set {fan_id} PWM to {pwm}")
                        else:
                            print(f"Failed to set {fan_id} PWM")
                    except ValueError:
                        print("Invalid PWM value")
                elif cmd[0] == 'scan':
                    registers = controller.scan_ec_registers()
                    print(f"Found {len(registers)} non-zero registers")
                else:
                    print("Unknown command")
                    
            except KeyboardInterrupt:
                break
            except EOFError:
                break
    
    finally:
        controller.close_ec()
        print("\n🔥 EC Fan Control closed")

if __name__ == "__main__":
    main() 