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
