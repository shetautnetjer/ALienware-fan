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
