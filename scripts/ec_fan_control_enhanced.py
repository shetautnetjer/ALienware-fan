#!/usr/bin/env python3
"""
🔥 Alienware EC Fan Control Enhanced
Advanced EC access for fan control on Alienware laptops
"""

import os
import time
import struct
from typing import Dict, List, Optional, Tuple

class ECAccessEnhanced:
    """Enhanced EC access for fan control"""
    
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
        if not self.write_port(self.ec_ports['command'], command):
            return None
        time.sleep(0.01)
        return self.read_port(self.ec_ports['data'])
    
    def ec_write(self, command: int, value: int) -> bool:
        """Write to EC using command protocol"""
        if not self.write_port(self.ec_ports['command'], command):
            return False
        time.sleep(0.01)
        return self.write_port(self.ec_ports['data'], value)
    
    def smm_read(self, command: int) -> Optional[int]:
        """Read from EC using SMM protocol"""
        if not self.write_port(self.ec_ports['smm_command'], command):
            return None
        time.sleep(0.01)
        return self.read_port(self.ec_ports['smm_data'])
    
    def smm_write(self, command: int, value: int) -> bool:
        """Write to EC using SMM protocol"""
        if not self.write_port(self.ec_ports['smm_command'], command):
            return False
        time.sleep(0.01)
        return self.write_port(self.ec_ports['smm_data'], value)

class AlienwareFanControllerEnhanced:
    """Enhanced Alienware-specific fan controller"""
    
    def __init__(self):
        self.ec = ECAccessEnhanced()
        
        # Multiple command code sets to try
        self.fan_command_sets = {
            'set1': {  # Standard Dell commands
                'fan1': 0x30, 'fan2': 0x31, 'fan3': 0x32, 'fan4': 0x33, 'fan5': 0x34, 'fan6': 0x35
            },
            'set2': {  # Alternative Dell commands
                'fan1': 0x40, 'fan2': 0x41, 'fan3': 0x42, 'fan4': 0x43, 'fan5': 0x44, 'fan6': 0x45
            },
            'set3': {  # Alienware-specific commands
                'fan1': 0x50, 'fan2': 0x51, 'fan3': 0x52, 'fan4': 0x53, 'fan5': 0x54, 'fan6': 0x55
            },
            'set4': {  # High-performance commands
                'fan1': 0x60, 'fan2': 0x61, 'fan3': 0x62, 'fan4': 0x63, 'fan5': 0x64, 'fan6': 0x65
            },
            'set5': {  # SMM-based commands
                'fan1': 0x70, 'fan2': 0x71, 'fan3': 0x72, 'fan4': 0x73, 'fan5': 0x74, 'fan6': 0x75
            }
        }
        
        # Register-based fan control
        self.fan_registers = {
            'cpu_fan': 0x20,
            'gpu_fan': 0x24, 
            'vrm_fan': 0x28,
            'exhaust_fan': 0x2C,
            'chassis_fan': 0x30,
            'memory_fan': 0x34
        }
        
    def open_ec(self) -> bool:
        """Open EC access"""
        return self.ec.open_port()
    
    def close_ec(self):
        """Close EC access"""
        self.ec.close_port()
    
    def scan_fan_commands(self) -> Dict[str, Dict[str, int]]:
        """Scan all fan command sets to find working ones"""
        print("🔍 Scanning fan command sets...")
        working_commands = {}
        
        for set_name, commands in self.fan_command_sets.items():
            print(f"\nTesting {set_name}:")
            working_set = {}
            
            for fan_id, command in commands.items():
                # Try to read fan speed
                speed = self.ec.ec_read(command)
                if speed is not None and speed != 255:  # 255 usually means invalid
                    print(f"  {fan_id}: Command 0x{command:02X} -> Speed {speed}")
                    working_set[fan_id] = command
                else:
                    print(f"  {fan_id}: Command 0x{command:02X} -> No response")
            
            if working_set:
                working_commands[set_name] = working_set
                print(f"  ✅ {set_name} has {len(working_set)} working commands")
            else:
                print(f"  ❌ {set_name} has no working commands")
        
        return working_commands
    
    def scan_fan_registers(self) -> Dict[str, int]:
        """Scan fan control registers"""
        print("\n🔍 Scanning fan control registers...")
        working_registers = {}
        
        for fan_name, register in self.fan_registers.items():
            value = self.ec.read_port(register)
            if value is not None:
                print(f"  {fan_name}: Register 0x{register:02X} = 0x{value:02X} ({value})")
                working_registers[fan_name] = register
            else:
                print(f"  {fan_name}: Register 0x{register:02X} = No access")
        
        return working_registers
    
    def test_register_fan_control(self, register: int, fan_name: str):
        """Test fan control via direct register access"""
        print(f"\n🧪 Testing {fan_name} via register 0x{register:02X}")
        
        # Read current value
        current_value = self.ec.read_port(register)
        print(f"  Current value: 0x{current_value:02X} ({current_value})")
        
        # Test different values
        test_values = [0x00, 0x40, 0x80, 0xC0, 0xFF]
        
        for test_value in test_values:
            print(f"  Setting register to 0x{test_value:02X}...")
            
            # Write to register
            if self.ec.write_port(register, test_value):
                time.sleep(0.5)
                
                # Read back
                new_value = self.ec.read_port(register)
                print(f"    New value: 0x{new_value:02X} ({new_value})")
                
                if new_value == test_value:
                    print(f"    ✅ Register write successful!")
                else:
                    print(f"    ⚠️  Value reverted or changed")
            else:
                print(f"    ❌ Register write failed")
        
        # Restore original
        if current_value is not None:
            self.ec.write_port(register, current_value)
    
    def test_smm_fan_control(self):
        """Test SMM-based fan control"""
        print("\n🔧 Testing SMM-based fan control...")
        
        # Common SMM fan commands
        smm_commands = [0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87]
        
        for command in smm_commands:
            print(f"  Testing SMM command 0x{command:02X}...")
            
            # Try to read
            read_value = self.ec.smm_read(command)
            if read_value is not None:
                print(f"    Read: 0x{read_value:02X} ({read_value})")
                
                # Try to write
                test_value = 128
                if self.ec.smm_write(command, test_value):
                    time.sleep(0.5)
                    new_value = self.ec.smm_read(command)
                    print(f"    Write test: 0x{new_value:02X} ({new_value})")
                else:
                    print(f"    Write failed")
            else:
                print(f"    No response")
    
    def find_fan_patterns(self):
        """Find patterns in EC data that might indicate fan control"""
        print("\n🔍 Finding fan control patterns...")
        
        # Scan for patterns in the interesting registers we found
        interesting_registers = [0x20, 0x24, 0x28, 0x2C, 0x30, 0x34, 0x38, 0x3C, 0x40, 0x4E, 0x50, 0x60, 0x61, 0xA0, 0xA4, 0xA8, 0xAC, 0xB0, 0xB4, 0xB8, 0xBC]
        
        print("Interesting registers:")
        for reg in interesting_registers:
            value = self.ec.read_port(reg)
            if value is not None:
                print(f"  0x{reg:02X}: 0x{value:02X} ({value})")
        
        # Look for patterns
        print("\nPattern analysis:")
        
        # Registers with value 0x02
        regs_02 = [0x20, 0x24, 0x28, 0x2C, 0x30, 0x34, 0x38, 0x3C]
        print(f"  Registers with 0x02: {[f'0x{r:02X}' for r in regs_02]}")
        print(f"  Pattern: Every 4 bytes, likely fan control registers")
        
        # Registers with value 0x12
        regs_12 = [0xA0, 0xA4, 0xA8, 0xAC, 0xB0, 0xB4, 0xB8, 0xBC]
        print(f"  Registers with 0x12: {[f'0x{r:02X}' for r in regs_12]}")
        print(f"  Pattern: Every 4 bytes, likely fan status registers")
        
        # Test if these are actually fan control registers
        print("\nTesting potential fan control registers:")
        for reg in regs_02:
            print(f"  Testing register 0x{reg:02X}...")
            current = self.ec.read_port(reg)
            
            # Try setting to different values
            for test_val in [0x00, 0x40, 0x80, 0xFF]:
                if self.ec.write_port(reg, test_val):
                    time.sleep(0.2)
                    new_val = self.ec.read_port(reg)
                    if new_val == test_val:
                        print(f"    ✅ Register 0x{reg:02X} is writable! Set to 0x{test_val:02X}")
                        break
                    else:
                        print(f"    Value reverted: 0x{new_val:02X}")
            
            # Restore original
            if current is not None:
                self.ec.write_port(reg, current)
    
    def interactive_mode(self):
        """Interactive mode for testing"""
        print("\n🎮 Enhanced Interactive Mode")
        print("============================")
        print("Commands:")
        print("  scan_commands  - Scan all fan command sets")
        print("  scan_registers - Scan fan control registers")
        print("  test_register <reg> <name> - Test specific register")
        print("  test_smm       - Test SMM fan control")
        print("  find_patterns  - Find fan control patterns")
        print("  read <port>    - Read EC port")
        print("  write <port> <value> - Write to EC port")
        print("  quit           - Exit")
        
        while True:
            try:
                cmd = input("\nEC> ").strip().split()
                if not cmd:
                    continue
                
                if cmd[0] == 'quit':
                    break
                elif cmd[0] == 'scan_commands':
                    self.scan_fan_commands()
                elif cmd[0] == 'scan_registers':
                    self.scan_fan_registers()
                elif cmd[0] == 'test_register' and len(cmd) == 3:
                    try:
                        reg = int(cmd[1], 16)
                        name = cmd[2]
                        self.test_register_fan_control(reg, name)
                    except ValueError:
                        print("Invalid register value")
                elif cmd[0] == 'test_smm':
                    self.test_smm_fan_control()
                elif cmd[0] == 'find_patterns':
                    self.find_fan_patterns()
                elif cmd[0] == 'read' and len(cmd) == 2:
                    try:
                        port = int(cmd[1], 16)
                        value = self.ec.read_port(port)
                        if value is not None:
                            print(f"Port 0x{port:02X}: 0x{value:02X} ({value})")
                        else:
                            print(f"Could not read port 0x{port:02X}")
                    except ValueError:
                        print("Invalid port value")
                elif cmd[0] == 'write' and len(cmd) == 3:
                    try:
                        port = int(cmd[1], 16)
                        value = int(cmd[2], 16)
                        if self.ec.write_port(port, value):
                            print(f"Wrote 0x{value:02X} to port 0x{port:02X}")
                        else:
                            print(f"Failed to write to port 0x{port:02X}")
                    except ValueError:
                        print("Invalid port or value")
                else:
                    print("Unknown command")
                    
            except KeyboardInterrupt:
                break
            except EOFError:
                break

def main():
    """Main function"""
    print("🔥 Alienware EC Fan Control Enhanced")
    print("====================================")
    
    # Check if running as root
    if os.geteuid() != 0:
        print("❌ This script requires root privileges")
        print("Run with: sudo python3 ec_fan_control_enhanced.py")
        return
    
    controller = AlienwareFanControllerEnhanced()
    
    if not controller.open_ec():
        print("❌ Failed to open EC access")
        return
    
    try:
        # Initial scan
        controller.scan_fan_commands()
        controller.scan_fan_registers()
        controller.find_fan_patterns()
        
        # Interactive mode
        controller.interactive_mode()
    
    finally:
        controller.close_ec()
        print("\n🔥 Enhanced EC Fan Control closed")

if __name__ == "__main__":
    main() 