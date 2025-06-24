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
