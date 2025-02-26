#!/bin/bash

# Get the script's directory path
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Activate the conda environment
source /opt/homebrew/anaconda3/bin/activate mustang_env 2>/dev/null || true

# Make sure we have pyusb and other dependencies installed
pip install pyusb mido python-rtmidi >/dev/null 2>&1

# Check arguments
if [ $# -eq 0 ]; then
  echo "Mustang Amp Control Script"
  echo "--------------------------"
  echo ""
  echo "Commands:"
  echo "  create-port              Create a virtual MIDI port"
  echo "  midi-ports               List available MIDI ports"
  echo "  preset <number>          Change to preset number (0-99)"
  echo "  gain <value>             Set gain (0-127)"
  echo "  volume <value>           Set volume (0-127)"
  echo "  bass <value>             Set bass (0-127)"
  echo "  mid <value>              Set mid (0-127)"
  echo "  treble <value>           Set treble (0-127)"
  echo "  master <value>           Set master volume (0-127)"
  echo "  modulation <on|off>      Turn modulation on/off"
  echo "  delay <on|off>           Turn delay on/off"
  echo "  reverb <on|off>          Turn reverb on/off"
  echo "  stomp <on|off>           Turn stomp on/off"
  echo "  tuner <on|off>           Turn tuner on/off"
  echo ""
  echo "Examples:"
  echo "  ./run_mustang.sh preset 10"
  echo "  ./run_mustang.sh gain 100"
  echo "  ./run_mustang.sh reverb on"
  exit 0
fi

# Process commands
COMMAND=$1
shift

case $COMMAND in
  "create-port")
    python "$SCRIPT_DIR/create_virtual_port.py" "$@"
    ;;
    
  "midi-ports")
    python -c "import mido; print('Available MIDI ports:'); ports = mido.get_output_names(); [print(f'  {i}: {p}') for i, p in enumerate(ports)]"
    ;;
    
  "preset")
    if [ $# -ne 1 ]; then
      echo "Usage: ./run_mustang.sh preset <number>"
      exit 1
    fi
    python "$SCRIPT_DIR/direct_control.py" "$1"
    ;;
    
  "gain")
    if [ $# -ne 1 ]; then
      echo "Usage: ./run_mustang.sh gain <value>"
      exit 1
    fi
    
    # Check if we have a MIDI port
    PORTS=$(python -c "import mido; print(len(mido.get_output_names()))")
    if [ "$PORTS" -gt 0 ]; then
      PORT=$(python -c "import mido; print(mido.get_output_names()[0])")
      python "$SCRIPT_DIR/amp_control.py" "$PORT" 69 "$1"
    else
      echo "No MIDI ports found. Create a virtual port with 'create-port' first."
      exit 1
    fi
    ;;
    
  "volume")
    if [ $# -ne 1 ]; then
      echo "Usage: ./run_mustang.sh volume <value>"
      exit 1
    fi
    
    # Check if we have a MIDI port
    PORTS=$(python -c "import mido; print(len(mido.get_output_names()))")
    if [ "$PORTS" -gt 0 ]; then
      PORT=$(python -c "import mido; print(mido.get_output_names()[0])")
      python "$SCRIPT_DIR/amp_control.py" "$PORT" 70 "$1"
    else
      echo "No MIDI ports found. Create a virtual port with 'create-port' first."
      exit 1
    fi
    ;;
    
  "treble")
    if [ $# -ne 1 ]; then
      echo "Usage: ./run_mustang.sh treble <value>"
      exit 1
    fi
    
    # Check if we have a MIDI port
    PORTS=$(python -c "import mido; print(len(mido.get_output_names()))")
    if [ "$PORTS" -gt 0 ]; then
      PORT=$(python -c "import mido; print(mido.get_output_names()[0])")
      python "$SCRIPT_DIR/amp_control.py" "$PORT" 71 "$1"
    else
      echo "No MIDI ports found. Create a virtual port with 'create-port' first."
      exit 1
    fi
    ;;
    
  "mid")
    if [ $# -ne 1 ]; then
      echo "Usage: ./run_mustang.sh mid <value>"
      exit 1
    fi
    
    # Check if we have a MIDI port
    PORTS=$(python -c "import mido; print(len(mido.get_output_names()))")
    if [ "$PORTS" -gt 0 ]; then
      PORT=$(python -c "import mido; print(mido.get_output_names()[0])")
      python "$SCRIPT_DIR/amp_control.py" "$PORT" 72 "$1"
    else
      echo "No MIDI ports found. Create a virtual port with 'create-port' first."
      exit 1
    fi
    ;;
    
  "bass")
    if [ $# -ne 1 ]; then
      echo "Usage: ./run_mustang.sh bass <value>"
      exit 1
    fi
    
    # Check if we have a MIDI port
    PORTS=$(python -c "import mido; print(len(mido.get_output_names()))")
    if [ "$PORTS" -gt 0 ]; then
      PORT=$(python -c "import mido; print(mido.get_output_names()[0])")
      python "$SCRIPT_DIR/amp_control.py" "$PORT" 73 "$1"
    else
      echo "No MIDI ports found. Create a virtual port with 'create-port' first."
      exit 1
    fi
    ;;
    
  "master")
    if [ $# -ne 1 ]; then
      echo "Usage: ./run_mustang.sh master <value>"
      exit 1
    fi
    
    # Check if we have a MIDI port
    PORTS=$(python -c "import mido; print(len(mido.get_output_names()))")
    if [ "$PORTS" -gt 0 ]; then
      PORT=$(python -c "import mido; print(mido.get_output_names()[0])")
      python "$SCRIPT_DIR/amp_control.py" "$PORT" 76 "$1"
    else
      echo "No MIDI ports found. Create a virtual port with 'create-port' first."
      exit 1
    fi
    ;;
    
  "tuner")
    if [ $# -ne 1 ] || ([ "$1" != "on" ] && [ "$1" != "off" ]); then
      echo "Usage: ./run_mustang.sh tuner <on|off>"
      exit 1
    fi
    
    VALUE=0
    if [ "$1" == "on" ]; then
      VALUE=127
    fi
    
    # Check if we have a MIDI port
    PORTS=$(python -c "import mido; print(len(mido.get_output_names()))")
    if [ "$PORTS" -gt 0 ]; then
      PORT=$(python -c "import mido; print(mido.get_output_names()[0])")
      python "$SCRIPT_DIR/amp_control.py" "$PORT" 20 "$VALUE"
    else
      echo "No MIDI ports found. Create a virtual port with 'create-port' first."
      exit 1
    fi
    ;;
    
  *)
    echo "Unknown command: $COMMAND"
    echo "Run ./run_mustang.sh without arguments to see available commands."
    exit 1
    ;;
esac