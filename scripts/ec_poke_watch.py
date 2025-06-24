#!/usr/bin/env python3
# scripts/ec_poke_watch.py

import os
import time
import struct
import logging
from datetime import datetime
from typing import List, Tuple, Optional

class ECPokeWatcher:
    def __init__(self, log_file: str = None):
        self.log_file = log_file or f"/var/log/fan_debug/ec_poke_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        self.ec_start = 0x02A0
        self.ec_end = 0x02FF
        self.stride = 2
        self.duty_cycles = [0x16, 0x32, 0x64, 0x96, 0xC8, 0xFF]
        self.hits_file = f"{self.log_file}.hits"
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
        # Create backup of current EC state
        self._create_ec_backup()
    
    def _create_ec_backup(self):
        """Create backup of current EC state"""
        backup_file = f"{self.log_file}.ec_backup"
        self.logger.info(f"Creating EC backup to {backup_file}")
        
        try:
            with open("/dev/port", "rb") as port:
                with open(backup_file, "wb") as backup:
                    for addr in range(self.ec_start, self.ec_end + 1, self.stride):
                        port.seek(addr)
                        backup.write(port.read(1))
        except Exception as e:
            self.logger.error(f"Failed to create EC backup: {e}")
    
    def get_fan_speeds(self) -> List[int]:
        """Get current fan speeds from all hwmon devices"""
        speeds = []
        try:
            for hwmon_dir in os.listdir("/sys/class/hwmon"):
                hwmon_path = f"/sys/class/hwmon/{hwmon_dir}"
                if os.path.isdir(hwmon_path):
                    for fan_file in os.listdir(hwmon_path):
                        if fan_file.startswith("fan") and fan_file.endswith("_input"):
                            fan_path = f"{hwmon_path}/{fan_file}"
                            try:
                                with open(fan_path, "r") as f:
                                    rpm = int(f.read().strip())
                                    speeds.append(rpm)
                            except (ValueError, IOError):
                                speeds.append(0)
        except Exception as e:
            self.logger.error(f"Error reading fan speeds: {e}")
        
        return speeds
    
    def read_ec_reg(self, addr: int) -> Optional[int]:
        """Read EC register safely"""
        try:
            with open("/dev/port", "rb") as port:
                port.seek(addr)
                data = port.read(1)
                return struct.unpack('B', data)[0] if data else None
        except Exception as e:
            self.logger.error(f"Failed to read EC register 0x{addr:04X}: {e}")
            return None
    
    def write_ec_reg(self, addr: int, value: int) -> bool:
        """Write EC register safely"""
        try:
            with open("/dev/port", "wb") as port:
                port.seek(addr)
                port.write(struct.pack('B', value))
                return True
        except Exception as e:
            self.logger.error(f"Failed to write EC register 0x{addr:04X}: {e}")
            return False
    
    def test_register(self, addr: int) -> bool:
        """Test if register controls a fan"""
        self.logger.info(f"Testing EC register 0x{addr:04X}...")
        
        # Get baseline fan speeds
        baseline_speeds = self.get_fan_speeds()
        self.logger.info(f"  Baseline RPM: {baseline_speeds}")
        
        # Test each duty cycle
        for duty in self.duty_cycles:
            self.logger.info(f"    Testing duty cycle 0x{duty:02X}...")
            
            # Write duty cycle
            if not self.write_ec_reg(addr, duty):
                continue
            
            # Wait for fan response
            time.sleep(2)
            
            # Check fan speeds
            current_speeds = self.get_fan_speeds()
            self.logger.info(f"    Current RPM: {current_speeds}")
            
            # Check for RPM changes
            if current_speeds != baseline_speeds:
                self.logger.warning(f"POTENTIAL FAN REGISTER: 0x{addr:04X} at duty 0x{duty:02X}")
                self.logger.warning(f"  RPM change: {baseline_speeds} -> {current_speeds}")
                
                # Test reversibility
                self.logger.info("    Testing reversibility...")
                self.write_ec_reg(addr, 0x00)
                time.sleep(3)
                final_speeds = self.get_fan_speeds()
                
                if final_speeds == baseline_speeds:
                    self.logger.warning(f"REVERSIBLE: Register 0x{addr:04X} confirmed as fan control")
                    with open(self.hits_file, "a") as f:
                        f.write(f"0x{addr:04X}:0x{duty:02X}\n")
                    return True
                else:
                    self.logger.warning(f"NOT REVERSIBLE: Register 0x{addr:04X} may affect other systems")
            
            # Restore baseline
            self.write_ec_reg(addr, 0x00)
            time.sleep(1)
        
        return False
    
    def run_discovery(self):
        """Run the complete EC discovery process"""
        self.logger.info("=== EC POKE & WATCH SESSION START ===")
        self.logger.info(f"System: {os.uname()}")
        self.logger.info(f"EC Range: 0x{self.ec_start:04X}-0x{self.ec_end:04X}, Stride: {self.stride}")
        self.logger.info(f"Duty Cycles: {[f'0x{x:02X}' for x in self.duty_cycles]}")
        
        discovered_fans = []
        
        # Test each register
        for addr in range(self.ec_start, self.ec_end + 1, self.stride):
            if self.test_register(addr):
                discovered_fans.append(addr)
        
        self.logger.info("=== EC POKE & WATCH SESSION END ===")
        self.logger.info(f"Discovered {len(discovered_fans)} potential fan registers")
        self.logger.info(f"Check {self.hits_file} for confirmed fan registers")
        
        return discovered_fans

if __name__ == "__main__":
    import sys
    
    if os.geteuid() != 0:
        print("This script must be run as root")
        sys.exit(1)
    
    watcher = ECPokeWatcher()
    discovered = watcher.run_discovery()
    
    print(f"\nDiscovered fan registers: {[f'0x{x:04X}' for x in discovered]}") 