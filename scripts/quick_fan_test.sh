#!/bin/bash

# 🔥 Quick Fan Control Test
# Simple test of the unlocked fan control registers

echo "🔥 Quick Fan Control Test"
echo "========================="
echo "Testing unlocked fan control registers..."
echo ""

# Function to set fan speed
set_fan() {
    local register="$1"
    local pwm="$2"
    local name="$3"
    
    echo "Setting $name (Register 0x$register) to PWM $pwm..."
    
    # Convert decimal to hex
    pwm_hex=$(printf "%02X" "$pwm")
    
    # Write to register
    if echo -ne "\x$pwm_hex" | sudo dd of=/dev/port bs=1 count=1 seek=$((0x$register)) 2>/dev/null; then
        echo "  ✅ $name set to PWM $pwm"
        
        # Wait and read back
        sleep 1
        value=$(sudo dd if=/dev/port bs=1 count=1 skip=$((0x$register)) 2>/dev/null | od -An -tu1)
        echo "  Register value: $value"
    else
        echo "  ❌ Failed to set $name"
    fi
}

# Show current status
echo "📊 Current Register Values:"
registers=("20" "24" "28" "2C" "30" "34" "38" "3C")
names=("CPU" "GPU" "VRM" "Exhaust" "Chassis" "Memory" "Additional1" "Additional2")

for i in "${!registers[@]}"; do
    register="${registers[$i]}"
    name="${names[$i]}"
    value=$(sudo dd if=/dev/port bs=1 count=1 skip=$((0x$register)) 2>/dev/null | od -An -tu1)
    echo "  $name Fan (0x$register): $value"
done

echo ""
echo "🧪 Testing Fan Control..."
echo "========================"

# Test setting each fan to different speeds
echo "Setting all fans to PWM 64 (25%)..."
set_fan "24" "64" "GPU Fan"
set_fan "28" "64" "VRM Fan"
set_fan "2C" "64" "Exhaust Fan"
set_fan "30" "64" "Chassis Fan"
set_fan "34" "64" "Memory Fan"
set_fan "38" "64" "Additional Fan 1"
set_fan "3C" "64" "Additional Fan 2"

echo ""
echo "Waiting 3 seconds..."
sleep 3

echo ""
echo "Setting all fans to PWM 128 (50%)..."
set_fan "24" "128" "GPU Fan"
set_fan "28" "128" "VRM Fan"
set_fan "2C" "128" "Exhaust Fan"
set_fan "30" "128" "Chassis Fan"
set_fan "34" "128" "Memory Fan"
set_fan "38" "128" "Additional Fan 1"
set_fan "3C" "128" "Additional Fan 2"

echo ""
echo "Waiting 3 seconds..."
sleep 3

echo ""
echo "Setting all fans to PWM 192 (75%)..."
set_fan "24" "192" "GPU Fan"
set_fan "28" "192" "VRM Fan"
set_fan "2C" "192" "Exhaust Fan"
set_fan "30" "192" "Chassis Fan"
set_fan "34" "192" "Memory Fan"
set_fan "38" "192" "Additional Fan 1"
set_fan "3C" "192" "Additional Fan 2"

echo ""
echo "Waiting 3 seconds..."
sleep 3

echo ""
echo "Setting all fans to PWM 255 (100%)..."
set_fan "24" "255" "GPU Fan"
set_fan "28" "255" "VRM Fan"
set_fan "2C" "255" "Exhaust Fan"
set_fan "30" "255" "Chassis Fan"
set_fan "34" "255" "Memory Fan"
set_fan "38" "255" "Additional Fan 1"
set_fan "3C" "255" "Additional Fan 2"

echo ""
echo "Final Register Values:"
for i in "${!registers[@]}"; do
    register="${registers[$i]}"
    name="${names[$i]}"
    value=$(sudo dd if=/dev/port bs=1 count=1 skip=$((0x$register)) 2>/dev/null | od -An -tu1)
    echo "  $name Fan (0x$register): $value"
done

echo ""
echo "🎉 Fan control test completed!"
echo "Check if fan speeds changed in hwmon6:"
echo "  cat /sys/class/hwmon/hwmon6/fan*_input" 