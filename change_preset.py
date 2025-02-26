#!/usr/bin/env python3
# Simple script to change presets on Fender Mustang amp

import mido
import sys
import time

def list_ports():
    """List all available MIDI ports"""
    outputs = mido.get_output_names()
    print("Available MIDI output ports:")
    for i, port in enumerate(outputs):
        print(f"  {i}: {port}")

def change_preset(port_name, preset_number):
    """Change to the specified preset number"""
    if preset_number < 0 or preset_number > 99:
        print("Preset number must be between 0 and 99")
        return
    
    try:
        # Open the MIDI port
        print(f"Opening MIDI port: {port_name}")
        with mido.open_output(port_name) as outport:
            # Create a program change message
            msg = mido.Message('program_change', program=preset_number)
            print(f"Sending program change to preset {preset_number}")
            outport.send(msg)
            time.sleep(0.5)  # Give time for the message to be processed
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # Check command line arguments
    if len(sys.argv) == 1:
        list_ports()
        print("\nUsage: python change_preset.py <port_name> <preset_number>")
        print("Example: python change_preset.py 'Mustang MIDI' 10")
        sys.exit(0)
    
    if len(sys.argv) != 3:
        print("Error: Incorrect number of arguments")
        print("Usage: python change_preset.py <port_name> <preset_number>")
        sys.exit(1)
    
    port_name = sys.argv[1]
    try:
        preset_number = int(sys.argv[2])
    except ValueError:
        print("Error: Preset number must be an integer")
        sys.exit(1)
    
    change_preset(port_name, preset_number)