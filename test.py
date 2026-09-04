#!/usr/bin/env python3
#
# Interactive regression tests for mustang_midi.  Requires a connected
# amp with an LCD (Mustang III/IV/V) so you can watch the edits happen.
#
# hirsch@z87:~$ aconnect -o
# client 14: 'Midi Through' [type=kernel]
#    0 'Midi Through Port-0'
# client 128: 'RtMidi Input Client' [type=user]
#    0 'TestPort        '
#
# Given the above, open RtMidi as: 'RtMidi Input Client 128:0'

from time import sleep
import sys
import itertools as it
import mido
mido.set_backend('mido.backends.rtmidi')

pc = mido.Message('program_change')
cc = mido.Message('control_change')

# 1 == v1, 2 == v2
amp_type = 0

TESTS = ("pc", "tuner", "efxbypass", "stomp", "mod", "reverb", "delay", "amp")


def analog_send(outport, sleeptime=0.25):
    """Sweep a continuous control through its range"""
    for value in [0, 32, 64, 96, 127, 0]:
        cc.value = value
        outport.send(cc)
        sleep(sleeptime)


def discrete_send(outport, max_value):
    """Step a discrete control through 0..max_value and back to 0"""
    for value in it.chain(range(0, max_value + 1), range(0, 1)):
        cc.value = value
        outport.send(cc)
        sleep(0.25)


def send_template(outport, first_cc, template, start=0):
    """Drive consecutive controls starting at first_cc according to a
    template string:  'A' = analog sweep, 'Dnn' = discrete 0..nn,
    '-' = skip this control."""
    limit = len(template)
    control = first_cc
    j = start
    while j < limit:
        cc.control = control
        control += 1
        if template[j] == "A":
            analog_send(outport)
        elif template[j] == "D":
            count = int(template[j + 1:j + 3])
            j += 2
            discrete_send(outport, count)
        elif template[j] == "-":
            pass
        j += 1


def model_select(outport, control, count):
    """Step through every model ordinal for a DSP"""
    cc.control = control
    for i in range(0, count):
        cc.value = i
        outport.send(cc)
        sleep(0.5)


def run_dsp_test(name, model_cc, first_parm_cc, model_count, struct, outport):
    input(f"Hit ENTER to run {name} model select test...\n")
    model_select(outport, model_cc, model_count)

    for model_name, ordinal, template, v2_only in struct:
        if v2_only and amp_type != 2:
            continue
        input(f"Hit ENTER to run parm edit check for {model_name}\n")
        cc.control = model_cc
        cc.value = ordinal
        outport.send(cc)
        input(f"Enter {name} edit mode on Mustang and hit ENTER to proceed...\n")
        send_template(outport, first_parm_cc, template)


def run_amp_test(struct, outport):
    input("Hit ENTER to run amp model select test...\n")
    model_select(outport, 68, 18 if amp_type == 2 else 13)

    for model_name, ordinal, template, v2_only in struct:
        if v2_only and amp_type != 2:
            continue
        input(f"Hit ENTER to run parm edit check for {model_name}\n")
        cc.control = 68
        cc.value = ordinal
        outport.send(cc)
        input("Enter amp edit mode on Mustang and hit ENTER to proceed...\n")
        # Screen 1 (gain, volume, treble, mid, bass) is the same for all models
        send_template(outport, 69, template[:5])
        input("Step to amp edit screen 2 and hit ENTER...\n")
        send_template(outport, 74, template, start=5)


def run_reverb_test(outport):
    input("Hit ENTER to run reverb model select test...\n")
    model_select(outport, 58, 11)
    input("Enter Reverb edit mode and hit ENTER...\n")
    send_template(outport, 59, "AAAAA")


def program_change_test(outport):
    input("Hit ENTER to run program change test...\n")
    for i in (0, 25, 75, 99, 60, 40, 20, 0):
        pc.program = i
        outport.send(pc)
        sleep(0.5)


def tuner_test(outport):
    input("Hit ENTER to select tuner...\n")
    cc.control = 20
    cc.value = 127
    outport.send(cc)
    input("Hit ENTER to deselect tuner...\n")
    cc.value = 0
    outport.send(cc)


def bypass_test(outport):
    input("Hit ENTER to select all effects...\n")
    cc.control = 22
    cc.value = 127
    outport.send(cc)
    input("Hit ENTER to bypass all effects...\n")
    cc.value = 0
    outport.send(cc)


#      Model            Ordinal  Template   v2only
STOMP_TESTS = (
    ("Ranger Boost",  8, "AAAA",    True),
    ("Green Box",     9, "AAAA",    True),
    ("Orange Box",   10, "AAA",     True),
    ("Black Box",    11, "AAA",     True),
    ("Big Fuzz",     12, "AAA",     True),

    ("Overdrive",     1, "AAAAA",   False),
    ("Wah",           2, "AAAAD01", False),
    ("Simple Comp",   6, "D03",     False),
    ("Comp",          7, "AAAAA",   False),
)

MOD_TESTS = (
    ("Wah",          12, "AAAAD01",     True),
    ("Touch Wah",    13, "AAAAD01",     True),
    ("Dia Shift",    14, "AD21D11D08A", True),

    ("Sine Chorus",   1, "AAAAA",   False),
    ("Vibratone",     5, "AAAAA",   False),
    ("Vintage Trem",  6, "AAAAA",   False),
    ("Ring Mod",      8, "AAAD01A", False),
    ("Phaser",       10, "AAAAD01", False),
    ("Pitch Shift",  11, "AAAAA",   False),
)

DELAY_TESTS = (
    ("Mono Delay",          1, "AAAAA",   False),
    ("Mono Echo Filter",    2, "AAAAAA",  False),
    ("Stereo Echo Filter",  3, "AAAAAA",  False),
    ("Multitap",            4, "AAAAD03", False),
    ("Tape Delay",          8, "AAAAAA",  False),
    ("Stereo Tape Delay",   9, "AAAAAA",  False),
)

# First five entries are screen 1 (CC 69-73), the rest screen 2 (CC 74..)
AMP_TESTS = (
    ("Studio Preamp",      13, "AAAAA--D04D12",      True),
    ("Fender 65 Twin",      6, "AAAAAD02AD04D12",    False),
    ("Fender SuperSonic",   7, "AAAAAD02AD04D12AA",  False),
    ("British 60s",         8, "AAAAAD02AD04D12AA",  False),
    ("British 70s",         9, "AAAAAD02AD04D12AA",  False),
    ("British 80s",        10, "AAAAAD02AD04D12AA",  False),
)


###################### main ########################

def main():
    global amp_type
    args = sys.argv

    if len(args) < 4:
        print("Usage: test.py <controller_port> <midi_channel> <v1|v2> [test_name]\n")
        print(f"Pass test name in {{{', '.join(TESTS)}}} for single test\n")
        print("Default is to run all of them if no arg 4 passed\n")
        sys.exit(1)

    try:
        channel = int(args[2]) - 1
    except ValueError:
        print("Arg2 must be numeric!\n")
        sys.exit(1)
    if not 0 <= channel <= 15:
        print("MIDI channel must be 1..16\n")
        sys.exit(1)
    pc.channel = cc.channel = channel

    if args[3] == "v1":
        amp_type = 1
    elif args[3] == "v2":
        amp_type = 2
    else:
        print("Arg 3 must be 'v1' or 'v2'")
        sys.exit(1)

    single = "all"
    if len(args) >= 5:
        single = args[4]
        if single not in TESTS:
            print(f"Unknown test '{single}'. Choose from: {', '.join(TESTS)}")
            sys.exit(1)

    outport = mido.open_output(args[1])

    def selected(name):
        return single in ("all", name)

    if selected("pc"):
        program_change_test(outport)
    if selected("tuner"):
        tuner_test(outport)
    if selected("efxbypass"):
        bypass_test(outport)
    if selected("stomp"):
        run_dsp_test("stomp", 28, 29, 13 if amp_type == 2 else 8, STOMP_TESTS, outport)
    if selected("mod"):
        run_dsp_test("mod", 38, 39, 15 if amp_type == 2 else 12, MOD_TESTS, outport)
    if selected("reverb"):
        run_reverb_test(outport)
    if selected("delay"):
        run_dsp_test("delay", 48, 49, 10, DELAY_TESTS, outport)
    if selected("amp"):
        run_amp_test(AMP_TESTS, outport)

    print("All tests complete\n")


if __name__ == "__main__":
    main()
