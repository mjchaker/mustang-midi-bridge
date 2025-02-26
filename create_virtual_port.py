#!/usr/bin/env python
# Create a virtual MIDI port for Mustang amp

import mido
import rtmidi
import time
import sys

def create_virtual_port(port_name="Mustang Virtual MIDI"):
    """Create a virtual MIDI output port"""
    try:
        # Create a virtual MIDI output port
        midi_out = rtmidi.MidiOut()
        midi_out.open_virtual_port(port_name)
        print(f"Created virtual MIDI port: {port_name}")
        print("This port will remain active until you stop this script with Ctrl+C")
        
        # Keep the script running to maintain the virtual port
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nClosing virtual MIDI port")
            midi_out.close_port()
    except Exception as e:
        print(f"Error creating virtual MIDI port: {e}")
        return None

if __name__ == "__main__":
    # Check if a port name was provided
    port_name = "Mustang Virtual MIDI"
    if len(sys.argv) > 1:
        port_name = sys.argv[1]
    
    # Create the virtual port
    create_virtual_port(port_name)