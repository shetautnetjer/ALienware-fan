#!/bin/bash

# 🧪 Test EC Fan Control
# Simple test to verify EC fan control is working

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# EC fan registers
EC_FAN_REGISTERS=(
    "24:GPU Fan"
    "28:VRM Fan"
    "2C:Exhaust Fan"
    "30:Chassis Fan"
    "34:Memory Fan"
    "38:Additional Fan 1"
    "3C:Additional Fan 2"
)

echo -e "${BLUE}🧪 Testing EC Fan Control${NC}"
echo "=========================="

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script requires root privileges${NC}"
    exit 1
fi

# Function to set EC fan
set_ec_fan() {
    local register="$1"
    local pwm_value="$2"
    local fan_name="$3"
    
    local pwm_hex=$(printf "%02X" "$pwm_value")
    
    if echo -ne "\x$pwm_hex" | dd of=/dev/port bs=1 count=1 seek=$((0x$register)) 2>/dev/null; then
        echo -e "${GREEN}✅${NC} Set $fan_name (0x$register) to PWM $pwm_value"
        return 0
    else
        echo -e "${RED}❌${NC} Failed to set $fan_name (0x$register) to PWM $pwm_value"
        return 1
    fi
}

# Test 1: Set all fans to 25% (64 PWM)
echo -e "\n${YELLOW}Test 1: Setting all fans to 25% (PWM 64)${NC}"
for fan_info in "${EC_FAN_REGISTERS[@]}"; do
    register=$(echo "$fan_info" | cut -d: -f1)
    fan_name=$(echo "$fan_info" | cut -d: -f2)
    set_ec_fan "$register" "64" "$fan_name"
done

echo -e "\n${BLUE}Waiting 3 seconds...${NC}"
sleep 3

# Test 2: Set all fans to 50% (128 PWM)
echo -e "\n${YELLOW}Test 2: Setting all fans to 50% (PWM 128)${NC}"
for fan_info in "${EC_FAN_REGISTERS[@]}"; do
    register=$(echo "$fan_info" | cut -d: -f1)
    fan_name=$(echo "$fan_info" | cut -d: -f2)
    set_ec_fan "$register" "128" "$fan_name"
done

echo -e "\n${BLUE}Waiting 3 seconds...${NC}"
sleep 3

# Test 3: Set all fans to 75% (192 PWM)
echo -e "\n${YELLOW}Test 3: Setting all fans to 75% (PWM 192)${NC}"
for fan_info in "${EC_FAN_REGISTERS[@]}"; do
    register=$(echo "$fan_info" | cut -d: -f1)
    fan_name=$(echo "$fan_info" | cut -d: -f2)
    set_ec_fan "$register" "192" "$fan_name"
done

echo -e "\n${BLUE}Waiting 3 seconds...${NC}"
sleep 3

# Test 4: Set all fans to 100% (255 PWM)
echo -e "\n${YELLOW}Test 4: Setting all fans to 100% (PWM 255)${NC}"
for fan_info in "${EC_FAN_REGISTERS[@]}"; do
    register=$(echo "$fan_info" | cut -d: -f1)
    fan_name=$(echo "$fan_info" | cut -d: -f2)
    set_ec_fan "$register" "255" "$fan_name"
done

echo -e "\n${BLUE}Waiting 3 seconds...${NC}"
sleep 3

# Test 5: Restore BIOS control (PWM 0)
echo -e "\n${YELLOW}Test 5: Restoring BIOS control (PWM 0)${NC}"
for fan_info in "${EC_FAN_REGISTERS[@]}"; do
    register=$(echo "$fan_info" | cut -d: -f1)
    fan_name=$(echo "$fan_info" | cut -d: -f2)
    set_ec_fan "$register" "0" "$fan_name"
done

echo -e "\n${GREEN}✅ EC fan test completed!${NC}"
echo -e "${BLUE}Check fan speeds and temperatures to verify control is working.${NC}" 