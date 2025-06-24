#!/bin/bash

# 🔥 Alienware Fan Control GUI Setup Script
# This script sets up the GUI environment for the Alienware fan control project

set -e

echo "🔥 Alienware Fan Control GUI Setup"
echo "=================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  Warning: Running as root. GUI may not work properly."
   echo "   Consider running without sudo for GUI setup."
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install PyQt5
install_pyqt5() {
    echo "📦 Installing PyQt5..."
    
    if command_exists apt; then
        # Debian/Ubuntu
        sudo apt update
        sudo apt install -y python3-pyqt5 python3-pyqt5.qtwidgets python3-pyqt5.qtcore
    elif command_exists dnf; then
        # Fedora
        sudo dnf install -y python3-qt5
    elif command_exists pacman; then
        # Arch Linux
        sudo pacman -S --noconfirm python-pyqt5
    elif command_exists zypper; then
        # OpenSUSE
        sudo zypper install -y python3-qt5
    else
        echo "❌ Unsupported package manager. Please install PyQt5 manually."
        return 1
    fi
    
    echo "✅ PyQt5 installed successfully"
}

# Function to install additional dependencies
install_dependencies() {
    echo "📦 Installing additional dependencies..."
    
    if command_exists apt; then
        sudo apt install -y python3-psutil
    elif command_exists dnf; then
        sudo dnf install -y python3-psutil
    elif command_exists pacman; then
        sudo pacman -S --noconfirm python-psutil
    elif command_exists zypper; then
        sudo zypper install -y python3-psutil
    fi
    
    echo "✅ Dependencies installed successfully"
}

# Function to test GUI availability
test_gui() {
    echo "🧪 Testing GUI availability..."
    
    # Test PyQt5
    if python3 -c "import PyQt5.QtWidgets" 2>/dev/null; then
        echo "✅ PyQt5 is available"
        PYQT_AVAILABLE=true
    else
        echo "❌ PyQt5 is not available"
        PYQT_AVAILABLE=false
    fi
    
    # Test Tkinter
    if python3 -c "import tkinter" 2>/dev/null; then
        echo "✅ Tkinter is available"
        TKINTER_AVAILABLE=true
    else
        echo "❌ Tkinter is not available"
        TKINTER_AVAILABLE=false
    fi
}

# Function to create launcher scripts
create_launchers() {
    echo "🔧 Creating launcher scripts..."
    
    # Create PyQt5 launcher
    cat > alienfan_gui_pyqt.sh << 'EOF'
#!/bin/bash
# Alienware Fan Control GUI - PyQt5 Version

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root for fan control"
   echo "Run with: sudo $0"
   exit 1
fi

# Check if PyQt5 is available
if ! python3 -c "import PyQt5.QtWidgets" 2>/dev/null; then
    echo "PyQt5 is not available. Please install it first:"
    echo "  sudo apt install python3-pyqt5"
    exit 1
fi

# Run the PyQt5 GUI
python3 alienfan_gui_enhanced.py
EOF

    # Create Tkinter launcher
    cat > alienfan_gui_tkinter.sh << 'EOF'
#!/bin/bash
# Alienware Fan Control GUI - Tkinter Version

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root for fan control"
   echo "Run with: sudo $0"
   exit 1
fi

# Check if Tkinter is available
if ! python3 -c "import tkinter" 2>/dev/null; then
    echo "Tkinter is not available. Please install it first:"
    echo "  sudo apt install python3-tk"
    exit 1
fi

# Run the Tkinter GUI
python3 alienfan_gui_tkinter.py
EOF

    # Create smart launcher
    cat > alienfan_gui.sh << 'EOF'
#!/bin/bash
# Alienware Fan Control GUI - Smart Launcher

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root for fan control"
   echo "Run with: sudo $0"
   exit 1
fi

# Try PyQt5 first, fallback to Tkinter
if python3 -c "import PyQt5.QtWidgets" 2>/dev/null; then
    echo "🚀 Starting PyQt5 GUI..."
    python3 alienfan_gui_enhanced.py
elif python3 -c "import tkinter" 2>/dev/null; then
    echo "🚀 Starting Tkinter GUI..."
    python3 alienfan_gui_tkinter.py
else
    echo "❌ No GUI framework available"
    echo "Please install either PyQt5 or Tkinter:"
    echo "  sudo apt install python3-pyqt5"
    echo "  sudo apt install python3-tk"
    exit 1
fi
EOF

    # Make scripts executable
    chmod +x alienfan_gui_pyqt.sh
    chmod +x alienfan_gui_tkinter.sh
    chmod +x alienfan_gui.sh
    
    echo "✅ Launcher scripts created"
}

# Function to create desktop shortcut
create_desktop_shortcut() {
    echo "🖥️  Creating desktop shortcut..."
    
    if [[ -n "$XDG_DESKTOP_DIR" ]]; then
        DESKTOP_DIR="$XDG_DESKTOP_DIR"
    elif [[ -d "$HOME/Desktop" ]]; then
        DESKTOP_DIR="$HOME/Desktop"
    else
        echo "⚠️  Desktop directory not found, skipping desktop shortcut"
        return
    fi
    
    cat > "$DESKTOP_DIR/Alienware Fan Control.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Alienware Fan Control
Comment=Control Alienware laptop fans
Exec=sudo $PWD/alienfan_gui.sh
Icon=fan
Terminal=false
Categories=System;HardwareSettings;
EOF

    chmod +x "$DESKTOP_DIR/Alienware Fan Control.desktop"
    echo "✅ Desktop shortcut created"
}

# Function to show usage information
show_usage() {
    echo ""
    echo "🎯 Usage:"
    echo "  ./alienfan_gui.sh          # Smart launcher (recommended)"
    echo "  ./alienfan_gui_pyqt.sh     # PyQt5 GUI"
    echo "  ./alienfan_gui_tkinter.sh  # Tkinter GUI"
    echo ""
    echo "📋 Features:"
    echo "  • Live temperature and fan monitoring"
    echo "  • Individual fan control (Auto/Manual/Full Speed)"
    echo "  • Quick presets (Quiet, Balanced, Performance, Max)"
    echo "  • System information display"
    echo "  • Real-time logging"
    echo ""
    echo "⚠️  Note: GUI requires root privileges for fan control"
    echo "   Run with: sudo ./alienfan_gui.sh"
}

# Main setup process
main() {
    echo "🔍 Checking system..."
    
    # Test current GUI availability
    test_gui
    
    # Install PyQt5 if not available
    if [[ "$PYQT_AVAILABLE" == "false" ]]; then
        echo ""
        read -p "Install PyQt5? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_pyqt5
            test_gui  # Re-test after installation
        fi
    fi
    
    # Install additional dependencies
    install_dependencies
    
    # Create launcher scripts
    create_launchers
    
    # Create desktop shortcut
    create_desktop_shortcut
    
    echo ""
    echo "🎉 Setup complete!"
    show_usage
}

# Run main function
main "$@" 