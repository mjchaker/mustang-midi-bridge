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
        return False
    return True

def show_controls():
    """Display the controller numbers understood by mustang_midi (see midi_cc.h)"""
    print("\nControl Parameters (mustang_midi CC map):")
    print("  20: Tuner (0=off, 127=on)")
    print("  22: All effects (0=bypass, 127=active)")
    print("  23: Stomp on/off      24: Modulation on/off")
    print("  25: Delay on/off      26: Reverb on/off")
    print("  28: Stomp model (0=none, 1-7 v1, 8-12 v2 only)")
    print("  29-33: Stomp parameters")
    print("  38: Modulation model (0=none, 1-11 v1, 12-14 v2 only)")
    print("  39-43: Modulation parameters")
    print("  48: Delay model (0=none, 1-9)")
    print("  49-54: Delay parameters")
    print("  58: Reverb model (0=none, 1-10)")
    print("  59-63: Reverb parameters (level, decay, dwell, diffusion, tone)")
    print("  68: Amp model (0=none, 1-12 v1, 13-17 v2 only)")
    print("  69: Gain              70: Channel volume")
    print("  71: Treble            72: Middle")
    print("  73: Bass              74: Sag (0-2)")
    print("  75: Bias              76: Noise gate (0-4)")
    print("  77: Cabinet (0-12)    78: Presence / Gain 2 / Cut (model dependent)")
    print("  79: Master volume / Blend (model dependent)")
    print("Program Change 0-99 selects a preset.")

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
    if not (0 <= control <= 127 and 0 <= value <= 127):
        print("Error: Control number and value must be between 0 and 127")
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
    sys.exit(0 if send_control_change(port_name, control, value, channel) else 1)