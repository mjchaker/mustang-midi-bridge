#!/bin/bash

# Activate the conda environment
source /opt/homebrew/anaconda3/bin/activate mustang_env

# List available MIDI ports
echo "Available MIDI ports:"
python -c "import mido; print(mido.get_output_names())"

# Check if we're running a command or just listing ports
if [ $# -eq 0 ]; then
  echo ""
  echo "Usage examples:"
  echo "  ./run_midi.sh change_preset.py 'port_name' 10"
  echo "  ./run_midi.sh amp_control.py 'port_name' 69 100"
  echo ""
  echo "Run 'amp_control.py' without arguments to see all available controls"
  exit 0
fi

# Run the requested script with all arguments
python "$@"