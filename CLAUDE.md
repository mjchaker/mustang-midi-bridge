# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A bridge daemon (`mustang_midi`) that translates MIDI messages into the proprietary USB protocol of Fender Mustang amplifiers. Implements ~99% of the Fender Mustang Floor MIDI spec (see `doc/MIDX20_Midi_Spec.pdf`; reverse-engineered protocol notes in `doc/fender_mustang_protocol.txt`). Targets Linux (Raspberry Pi / Beaglebone deployment) and builds unchanged on macOS with Homebrew.

## Build Commands

- Build (optimized, default): `make`
- Build (debug, dumps every USB packet from the amp): `make debug`
- Build (explicit optimized): `make opt`
- Unit tests (no hardware needed): `make test`
- Clean: `make clean`
- Old rtmidi (`RtError` instead of `RtMidiError`): `make CPPFLAGS=-DRTMIDI_2_0`

The `Makefile` finds rtmidi and libusb-1.0 via `pkg-config` (falling back to `/usr/include/rtmidi` on Linux or the Homebrew prefix on macOS). Builds with `-Wall -Wextra` and is warning-free; keep it that way. Requires libusb-1.0, rtmidi, pthread; C++11. Linux deps: `apt-get install pkg-config librtmidi-dev libusb-1.0-0-dev`; macOS: `brew install rtmidi libusb pkg-config`. CI (`.github/workflows/build.yml`) builds and runs the unit tests on Ubuntu and macOS.

## Run Commands

- Run bridge on a hardware port: `./mustang_midi <controller_port#> <midi_channel#>`
- Run bridge with a virtual port: `./mustang_midi <virtual_port_name> <midi_channel#>` (channel is 1–16)
- Convenience wrapper: `./run_mustang.sh [command] [value]` (e.g., `gain 100`, `preset 10`, `tuner on`; run with no args for full command list)
- Create virtual MIDI port: `./run_mustang.sh create-port`
- List MIDI ports: `./run_mustang.sh midi-ports`

## Test Commands

- Unit tests: `make test` builds and runs `tests/test_dispatch.cpp`, which exercises the CC → USB byte-layout logic of the DSP handler classes without an amp. Add a case there whenever a CC mapping or model class changes.
- Hardware regression tests (`test.py`) are interactive and require a physically connected Mustang amp with an LCD.

- All tests: `python3 test.py <controller_port> <midi_channel> <v1|v2>`
- Single test: `python3 test.py <controller_port> <midi_channel> <v1|v2> [pc|tuner|efxbypass|stomp|mod|reverb|delay|amp]`
- Typical flow (see `README.testing`): start `mustang_midi "TestPort" 1`, find the assigned port with `aconnect -o`, then run `test.py "RtMidi Input Client 128:0" 1 v2`

Python dependencies: `pip install mido python-rtmidi pyusb`

## Architecture

Data flow: MIDI message → RtMidi callback → CC dispatch → `Mustang` method → USB command → amp; a listener thread reads amp responses and signals waiting commands.

### C++ daemon (the core)

- `mustang_midi.cpp` — `main()` plus the MIDI callback (`message_action`) and `dispatch_cc()`, which routes each controller to a `Mustang` method. The CC numbers live in `midi_cc.h`: CC 20 tuner, CC 22 all-effects bypass, CC 23–26 per-effect toggles, CC 28/38/48/58/68 select stomp/mod/delay/reverb/amp model, and CC ranges 29–33/39–43/49–54/59–63/69–79 for the corresponding DSP's parameters. Program Change selects presets 0–99. `main()` blocks the shutdown signals before any thread is created and waits in `sigsuspend()`, so SIGINT/SIGTERM/SIGHUP produce an orderly `commShutdown()`/`deinitialize()` (kernel driver reattached).
- `mustang.cpp/.h` — `Mustang` class owns all USB I/O (libusb-1.0, 64-byte packets, endpoints `0x01`/`0x81`). `initialize()` probes the `amp_ids[]` PID table to identify the amp and whether it's a v1 or v2 series (this determines the init magic byte and available models). `commStart()` spawns a pthread (`handleInput`) that continuously reads USB responses; command methods block on `Condition<T>` (pthread mutex + condvar) members via `awaitFlag()` until the listener thread sees the matching ack byte-prefix (e.g. `cc_ack`, `model_change_ack`) or `ACK_TIMEOUT_MS` elapses, in which case they return `LIBUSB_ERROR_TIMEOUT` rather than hanging the MIDI thread. State kept: `dsp_parms[6][64]` raw parameter blocks (indices `AMP_STATE`…`PEDAL_STATE` from `constants.h`) and 124 preset names. The `curr_*` handler pointers are NULL until the first state report for that DSP arrives; every user is NULL-guarded.
- `magic.cpp` — initialization handshake packet sequence sent at startup.
- `constants.h` — Fender USB VID/PIDs, DSP state-block indices, byte offset of the model ID (`MODEL` = 16).

### Per-DSP model class families

Each DSP category (amp, stomp, mod, delay, reverb) follows the same three-file pattern:

- `<dsp>.h/.cpp` — a base CC-handler class (`AmpCC`, `StompCC`, …) with virtual `cc##()` methods, one per MIDI CC. Each method encodes the USB parameter offsets for that control via `continuous_control()`/`discrete_control()`. Model-specific subclasses (defined in the same header) override the methods that differ, so the `cc##()` methods must stay `virtual`. `dispatch()` routes an incoming CC to the right method and returns -1 for anything it should not act on; the caller then sends nothing.
- `<dsp>_models.cpp/.h` — 2-byte USB model ID constants for every supported model (v2-only models flagged in comments).
- `<dsp>_defaults.h` — canned 64-byte parameter blocks sent when switching to a model, so it comes up with sane settings.

When the listener thread receives a DSP state block, `Mustang::update<Dsp>Obj()` reads the model ID at byte offset `MODEL` and swaps in the matching subclass instance (`curr_amp`, `curr_stomp`, …). To add a new model: add its ID to `<dsp>_models.*`, defaults to `<dsp>_defaults.h`, a subclass in `<dsp>.h` if its CC mapping differs, and wire it into the factory logic in `mustang.cpp`.

### Python utilities

- `amp_control.py` — send a single CC to a MIDI port (used by `run_mustang.sh`); with no arguments prints the CC map.
- `change_preset.py` — send a Program Change to a MIDI port.
- `create_virtual_port.py` — hold open a virtual MIDI port.
- `direct_control.py` — bypass MIDI entirely and talk USB directly via pyusb (protocol debugging only; cannot run while the daemon holds the USB interface).
- `test.py` — interactive regression tests.
- `run_mustang.sh` — wrapper over the above; `MUSTANG_MIDI_PORT` / `MUSTANG_MIDI_CHANNEL` select the target port and channel.

### Linux deployment (headless)

`install.sh` installs the binary, `mustang_bridge` init script, and udev rules (`50-mustang.rules`, `60-midi.rules`). The udev rules trigger `mustang_bridge_start` (Python 3 + pyusb), which auto-launches `mustang_midi` when both the amp and a configured MIDI controller (VID/PID edited at the top of that script) are plugged in; `mustang_bridge_stop` sends SIGINT, which the daemon handles as a clean shutdown.

## Code Style

- C++11; header guards; 2-space indent (C++), 4-space (Python, PEP 8)
- camelCase variables, PascalCase class names; opening braces on the same line
- Error handling by return code (0 = success, nonzero = failure) — no exceptions in the C++ core; RtMidi exceptions are caught at the boundary in `main()`
- const correctness; document public interfaces and protocol/byte-layout logic
- Build artifacts (`*.o`, `*.d`, `mustang_midi`, `test_dispatch`) are ignored via `.gitignore`; do not commit them
- Python scripts target Python 3 (`#!/usr/bin/env python3`)
