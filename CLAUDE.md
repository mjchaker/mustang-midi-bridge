# Mustang MIDI Bridge Usage Guide

## Build Commands
- Build (normal): `make`
- Build (debug): `make debug`
- Build (optimized): `make opt`
- Clean: `make clean`
- Legacy rtmidi build: `make CPPFLAGS=-DRTMIDI_2_0`

## Run Commands
- Create virtual MIDI port: `./run_mustang.sh create-port`
- List MIDI ports: `./run_mustang.sh midi-ports`
- Control amp: `./run_mustang.sh [command] [value]` (e.g., `./run_mustang.sh gain 100`)

## Test Commands
- Run regression tests: `python test.py <controller_port> <midi_channel> <v1|v2> [test_name]`
- Run single test: `python test.py <controller_port> <midi_channel> <v1|v2> [pc|tuner|efxbypass|amp]`
- Tests require a connected Mustang amp

## Python Dependencies
- mido: `pip install mido`
- rtmidi: `pip install python-rtmidi`
- pyusb: `pip install pyusb`

## Code Style
- C++: Use C++11 standard with header guards and class-based design
- C++ naming: camelCase for variables, PascalCase for class names
- Indentation: 2 spaces for C++, 4 spaces for Python
- Place opening braces on the same line as function declarations
- Use const correctness and virtual destructors for abstract classes
- Use standard memory management (avoid raw pointers)
- Python: Follow PEP 8 style guide, use descriptive function/variable names
- Error handling: Return error codes rather than using exceptions
- Comments: Document public interfaces and complex algorithms