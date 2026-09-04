#!/bin/bash
#
# Convenience wrapper around the Python MIDI helpers.  Every command is
# sent as a MIDI message to a running mustang_midi bridge; the bridge
# must already be listening on the port this script talks to.
#
# Port selection: set MUSTANG_MIDI_PORT to a port name (or substring)
# to choose the output port; otherwise the first available port is used.
# Channel selection: set MUSTANG_MIDI_CHANNEL (1..16, default 1).

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Activate the conda environment if there is one (optional)
source /opt/homebrew/anaconda3/bin/activate mustang_env 2>/dev/null || true

PYTHON=${PYTHON:-python3}

# Controller numbers understood by mustang_midi (see midi_cc.h)
CC_TUNER=20
CC_ALL_EFX=22
CC_STOMP_BYPASS=23
CC_MOD_BYPASS=24
CC_DELAY_BYPASS=25
CC_REVERB_BYPASS=26
CC_STOMP_MODEL=28
CC_MOD_MODEL=38
CC_DELAY_MODEL=48
CC_REVERB_MODEL=58
CC_AMP_MODEL=68
CC_GAIN=69
CC_VOLUME=70
CC_TREBLE=71
CC_MID=72
CC_BASS=73
CC_MASTER=79   # Master volume on the models that have one (CC 78/79 vary by amp model)

usage() {
  cat <<USAGE
Mustang Amp Control Script
--------------------------

Commands:
  create-port [name]       Create a virtual MIDI port
  midi-ports               List available MIDI ports
  preset <number>          Change to preset number (0-99)
  gain <value>             Set gain (0-127)
  volume <value>           Set channel volume (0-127)
  bass <value>             Set bass (0-127)
  mid <value>              Set mid (0-127)
  treble <value>           Set treble (0-127)
  master <value>           Set master volume (0-127, models with a master only)
  amp <ordinal>            Select amp model (0 = none)
  stomp <on|off|ordinal>   Toggle stomp or select stomp model
  modulation <on|off|ord>  Toggle modulation or select mod model
  delay <on|off|ordinal>   Toggle delay or select delay model
  reverb <on|off|ordinal>  Toggle reverb or select reverb model
  effects <on|off>         Toggle all effects
  tuner <on|off>           Turn tuner on/off
  cc <number> <value>      Send an arbitrary control change

Environment:
  MUSTANG_MIDI_PORT        Output port name or substring (default: first port)
  MUSTANG_MIDI_CHANNEL     MIDI channel 1-16 (default: 1)

Examples:
  ./run_mustang.sh preset 10
  ./run_mustang.sh gain 100
  ./run_mustang.sh reverb on
USAGE
}

need_python_deps() {
  if ! "$PYTHON" -c "import mido, rtmidi" 2>/dev/null; then
    echo "Missing Python dependencies. Install with:" >&2
    echo "  $PYTHON -m pip install mido python-rtmidi" >&2
    exit 1
  fi
}

# Resolve the MIDI output port to use
find_port() {
  "$PYTHON" - "${MUSTANG_MIDI_PORT:-}" <<'PY'
import sys, mido
want = sys.argv[1]
ports = mido.get_output_names()
if not ports:
    sys.exit(1)
if want:
    for p in ports:
        if want == p or want in p:
            print(p)
            sys.exit(0)
    sys.exit(2)
print(ports[0])
PY
}

send_cc() {
  local cc=$1 value=$2
  need_python_deps
  local port
  port=$(find_port)
  case $? in
    1) echo "No MIDI ports found. Start mustang_midi with a virtual port, or run 'create-port'." >&2; exit 1 ;;
    2) echo "No MIDI port matching '$MUSTANG_MIDI_PORT' found." >&2; exit 1 ;;
  esac
  local channel=$(( ${MUSTANG_MIDI_CHANNEL:-1} - 1 ))
  "$PYTHON" "$SCRIPT_DIR/amp_control.py" "$port" "$cc" "$value" "$channel"
}

# Check that exactly N arguments remain, else print usage line and exit
require_args() {
  local n=$1 msg=$2
  shift 2
  if [ $# -ne "$n" ]; then
    echo "Usage: ./run_mustang.sh $msg" >&2
    exit 1
  fi
}

require_range() {
  local value=$1 lo=$2 hi=$3 what=$4
  if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt "$lo" ] || [ "$value" -gt "$hi" ]; then
    echo "$what must be an integer between $lo and $hi" >&2
    exit 1
  fi
}

# on/off -> 127/0, or pass through a model ordinal for the model CC
toggle_or_model() {
  local bypass_cc=$1 model_cc=$2 name=$3
  shift 3
  require_args 1 "$name <on|off|ordinal>" "$@"
  case $1 in
    on)  send_cc "$bypass_cc" 127 ;;
    off) send_cc "$bypass_cc" 0 ;;
    *)   require_range "$1" 0 127 "$name model ordinal"; send_cc "$model_cc" "$1" ;;
  esac
}

on_off() {
  local cc=$1 name=$2
  shift 2
  require_args 1 "$name <on|off>" "$@"
  case $1 in
    on)  send_cc "$cc" 127 ;;
    off) send_cc "$cc" 0 ;;
    *)   echo "Usage: ./run_mustang.sh $name <on|off>" >&2; exit 1 ;;
  esac
}

continuous() {
  local cc=$1 name=$2
  shift 2
  require_args 1 "$name <value>" "$@"
  require_range "$1" 0 127 "$name"
  send_cc "$cc" "$1"
}

if [ $# -eq 0 ]; then
  usage
  exit 0
fi

COMMAND=$1
shift

case $COMMAND in
  create-port)
    need_python_deps
    "$PYTHON" "$SCRIPT_DIR/create_virtual_port.py" "$@"
    ;;

  midi-ports)
    need_python_deps
    "$PYTHON" -c "import mido; print('Available MIDI ports:'); [print(f'  {i}: {p}') for i, p in enumerate(mido.get_output_names())]"
    ;;

  preset)
    require_args 1 "preset <number>" "$@"
    require_range "$1" 0 99 "Preset number"
    need_python_deps
    port=$(find_port) || { echo "No MIDI port found." >&2; exit 1; }
    "$PYTHON" "$SCRIPT_DIR/change_preset.py" "$port" "$1"
    ;;

  gain)       continuous $CC_GAIN   gain   "$@" ;;
  volume)     continuous $CC_VOLUME volume "$@" ;;
  treble)     continuous $CC_TREBLE treble "$@" ;;
  mid)        continuous $CC_MID    mid    "$@" ;;
  bass)       continuous $CC_BASS   bass   "$@" ;;
  master)     continuous $CC_MASTER master "$@" ;;

  amp)
    require_args 1 "amp <ordinal>" "$@"
    require_range "$1" 0 127 "Amp model ordinal"
    send_cc $CC_AMP_MODEL "$1"
    ;;

  stomp)      toggle_or_model $CC_STOMP_BYPASS  $CC_STOMP_MODEL  stomp      "$@" ;;
  modulation) toggle_or_model $CC_MOD_BYPASS    $CC_MOD_MODEL    modulation "$@" ;;
  delay)      toggle_or_model $CC_DELAY_BYPASS  $CC_DELAY_MODEL  delay      "$@" ;;
  reverb)     toggle_or_model $CC_REVERB_BYPASS $CC_REVERB_MODEL reverb     "$@" ;;

  effects)    on_off $CC_ALL_EFX effects "$@" ;;
  tuner)      on_off $CC_TUNER   tuner   "$@" ;;

  cc)
    require_args 2 "cc <number> <value>" "$@"
    require_range "$1" 0 127 "Controller number"
    require_range "$2" 0 127 "Value"
    send_cc "$1" "$2"
    ;;

  help|-h|--help)
    usage
    ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Run ./run_mustang.sh without arguments to see available commands." >&2
    exit 1
    ;;
esac
