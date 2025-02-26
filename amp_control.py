#!/usr/bin/env python3
# Script to control Fender Mustang amp parameters

import mido
import sys
import time

def list_ports():
    """List all available MIDI ports"""
    outputs = mido.get_output_names()
    print("Available MIDI output ports:")
    for i, port in enumerate(outputs):
        print(f"  {i}: {port}")

def send_control_change(port_name, control, value, channel=0):
    """Send a control change message to the amp"""
    try:
        # Open the MIDI port
        print(f"Opening MIDI port: {port_name}")
        with mido.open_output(port_name) as outport:
            # Create a control change message
            msg = mido.Message('control_change', channel=channel, 
                              control=control, value=value)
            print(f"Sending control change: CC#{control} = {value}")
            outport.send(msg)
            time.sleep(0.5)  # Give time for the message to be processed
    except Exception as e:
        print(f"Error: {e}")

def show_controls():
    """Display available control parameters based on MIDI spec"""
    print("\nCommon Control Parameters:")
    print("  20: Tuner (0=off, 127=on)")
    print("  22: Effect Bypass (0=bypass, 127=active)")
    print("  68: Amp Model (0-18)")
    print("  69: Gain")
    print("  70: Volume")
    print("  71: Treble")
    print("  72: Middle")
    print("  73: Bass")
    print("  74: Presence/Cabinet")
    print("  75: Noise Gate")
    print("  76: Master Volume")
    print("  77: Gain2/Threshold")
    print("  78: Stomp Model (0-11)")
    print("  79: Stomp Enable (0=off, 127=on)")
    print("  80-83: Stomp Parameters")
    print("  84: Modulation Model (0-11)")
    print("  85: Modulation Enable (0=off, 127=on)")
    print("  86-89: Modulation Parameters")
    print("  90: Delay Model (0-8)")
    print("  91: Delay Enable (0=off, 127=on)")
    print("  92-95: Delay Parameters")
    print("  96: Reverb Model (0-8)")
    print("  97: Reverb Enable (0=off, 127=on)")
    print("  98-99: Reverb Parameters")

if __name__ == "__main__":
    # Show help if no arguments provided
    if len(sys.argv) == 1:
        list_ports()
        show_controls()
        print("\nUsage: python amp_control.py <port_name> <control_number> <value> [channel]")
        print("Example: python amp_control.py 'Mustang MIDI' 69 100   # Set gain to 100")
        sys.exit(0)
    
    # Check command line arguments
    if len(sys.argv) < 4:
        print("Error: Insufficient arguments")
        print("Usage: python amp_control.py <port_name> <control_number> <value> [channel]")
        sys.exit(1)
    
    # Parse arguments
    port_name = sys.argv[1]
    
    try:
        control = int(sys.argv[2])
        value = int(sys.argv[3])
    except ValueError:
        print("Error: Control number and value must be integers")
        sys.exit(1)
    
    # Optional channel parameter (0-15 for channels 1-16)
    channel = 0  # Default to channel 1
    if len(sys.argv) > 4:
        try:
            channel = int(sys.argv[4])
            if channel < 0 or channel > 15:
                raise ValueError("Channel must be between 0 and 15")
        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)
    
    # Send the control change
    send_control_change(port_name, control, value, channel)