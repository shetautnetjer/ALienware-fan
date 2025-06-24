#!/bin/bash

# 🔥 Alienware Fan Control Hack - Installation Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Please run this script as a regular user, not as root"
    exit 1
fi

log "=== ALIENWARE FAN CONTROL HACK INSTALLATION ==="

# Create log directory
log "Creating log directory..."
sudo mkdir -p /var/log/fan_debug
sudo chown $USER:$USER /var/log/fan_debug
success "Log directory created: /var/log/fan_debug"

# Make scripts executable
log "Making scripts executable..."
chmod +x scripts/*.sh
success "Scripts made executable"

# Install systemd service
log "Installing systemd service..."
sudo cp service/alienware-fan.service /etc/systemd/system/
sudo systemctl daemon-reload
success "Systemd service installed"

# Install scripts to /usr/local/bin
log "Installing scripts to /usr/local/bin..."
sudo cp scripts/fanwatch.sh /usr/local/bin/
sudo cp scripts/ec_probe.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/fanwatch.sh
sudo chmod +x /usr/local/bin/ec_probe.sh
success "Scripts installed to /usr/local/bin"

# Check for required packages
log "Checking for required packages..."

PACKAGES=("lm-sensors" "dmidecode" "stress-ng")

for package in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        warning "Package $package not installed"
        echo "You may want to install it with: sudo apt install $package"
    else
        success "Package $package is installed"
    fi
done

# Check for iasl (ACPI compiler)
if ! command -v iasl >/dev/null 2>&1; then
    warning "iasl (ACPI compiler) not found"
    echo "Install with: sudo apt install acpica-tools"
else
    success "iasl (ACPI compiler) is available"
fi

# Create initial log entry
log "Creating initial log entry..."
echo "=== INSTALLATION $(date) ===" >> /var/log/fan_debug/ec_trace.log
echo "System: $(uname -a)" >> /var/log/fan_debug/ec_trace.log
echo "User: $USER" >> /var/log/fan_debug/ec_trace.log
echo "Installation completed" >> /var/log/fan_debug/ec_trace.log

# Display usage instructions
echo ""
success "=== INSTALLATION COMPLETED ==="
echo ""
echo "📋 Quick Start Commands:"
echo "  ./scripts/fanwatch.sh          # Start fan monitoring"
echo "  ./scripts/ec_probe.sh          # Run EC probe tests"
echo "  sudo systemctl start alienware-fan.service  # Start as service"
echo "  sudo systemctl enable alienware-fan.service # Enable on boot"
echo ""
echo "📁 Log files location:"
echo "  /var/log/fan_debug/ec_trace.log"
echo "  /var/log/fan_debug/ec_probe.log"
echo ""
echo "🔍 Next Steps:"
echo "  1. Run: ./scripts/ec_probe.sh"
echo "  2. Check logs: tail -f /var/log/fan_debug/ec_trace.log"
echo "  3. Report findings on GitHub"
echo ""
echo "📚 Documentation:"
echo "  README.md - Project overview"
echo "  CONTRIBUTING.md - How to contribute"
echo ""
success "Happy hacking! 🔥" 