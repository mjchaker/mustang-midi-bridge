#!/usr/bin/env python
# Direct USB control of Mustang amp without MIDI
# Based on information from the mustang_bridge code

import usb.core
import usb.util
import time
import sys

# Mustang USB parameters
MUSTANG_VID = 0x1ed8
MUSTANG_PIDS = [0x0004, 0x0005, 0x000a, 0x0010, 0x0012, 0x0014, 0x0016]

# Endpoints for communication
EP_OUT = 0x01  # EP 1 OUT
EP_IN = 0x81   # EP 1 IN

def find_mustang_device():
    """Find the Mustang amp connected to the system"""
    for pid in MUSTANG_PIDS:
        device = usb.core.find(idVendor=MUSTANG_VID, idProduct=pid)
        if device:
            return device, pid
    return None, None

def change_preset(device, preset_number):
    """Change to the specified preset number (0-99)"""
    if preset_number < 0 or preset_number > 99:
        print("Preset number must be between 0 and 99")
        return False
    
    # Create the preset change command
    # Based on the USB protocol used in mustang_bridge
    command = bytearray([0x1c, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00])
    command[4] = preset_number
    
    try:
        # Send the command to the amp
        device.write(EP_OUT, command, 1000)
        print(f"Changed to preset {preset_number}")
        return True
    except Exception as e:
        print(f"Error changing preset: {e}")
        return False

def main():
    """Main function"""
    # Find the Mustang amp
    device, pid = find_mustang_device()
    if not device:
        print("No Mustang amp found. Make sure it's connected and powered on.")
        return
    
    print(f"Found Mustang amp (PID: 0x{pid:04x})")
    
    # Reset the device to make sure it's in a known state
    try:
        device.reset()
    except Exception as e:
        print(f"Warning: Could not reset device: {e}")
    
    # Set configuration
    try:
        device.set_configuration()
    except Exception as e:
        print(f"Warning: Could not set configuration: {e}")
    
    # Get command line arguments
    if len(sys.argv) != 2:
        print("Usage: python direct_control.py <preset_number>")
        print("Example: python direct_control.py 10")
        return
    
    try:
        preset_number = int(sys.argv[1])
    except ValueError:
        print("Error: Preset number must be an integer")
        return
    
    # Change the preset
    change_preset(device, preset_number)

if __name__ == "__main__":
    main()