#!/bin/bash
#
# Run one of the Python MIDI helpers with the project's Python
# environment, listing the available ports first.

# Activate the conda environment if there is one (optional)
source /opt/homebrew/anaconda3/bin/activate mustang_env 2>/dev/null || true

PYTHON=${PYTHON:-python3}

# List available MIDI ports
echo "Available MIDI ports:"
"$PYTHON" -c "import mido; print(mido.get_output_names())"

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
"$PYTHON" "$@"
