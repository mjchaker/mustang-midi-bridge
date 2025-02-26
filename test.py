#!/usr/bin/python3

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
type = 0

def analog_send(outport, sleeptime=0.25):
    for value in [0, 32, 64, 96, 127, 0]:
        cc.value = value
        outport.send(cc)
        sleep(sleeptime)

def discrete_send(outport, max_value):
    for value in it.chain(range(0, max_value+1), range(0, 1)):
        cc.value = value
        outport.send(cc)
        sleep(0.25)

def amp_screen1(outport):
    for i in range(69, 74):
        cc.control = i
        analog_send(outport)

def amp_screen2(outport, template):
    limit = len(template)
    i = 74
    j = 5
    while j < limit:
        cc.control = i
        i += 1
        if template[j] == "A":
            analog_send(outport)
        elif template[j] == "D":
            j += 1
            count = int(template[j:j+2])
            j += 1
            discrete_send(outport, count)
        j += 1

def amp_select(outport):
    max_value = 18 if type == 2 else 13
    cc.control = 68
    for i in range(0, max_value):
        cc.value = i
        outport.send(cc)
        sleep(0.5)

def run_amp_test(struct, outport):
    input("Hit ENTER to run amp model select test...\n")
    amp_select(outport)
    for control_rec in struct:
        if control_rec[3] and type != 2:
             continue
        input(f"Hit ENTER to run parm edit check for {control_rec[0]}\n")
        cc.control = 68
        cc.value = control_rec[1]
        outport.send(cc)
        input("Enter amp edit mode on Mustang and hit ENTER to proceed...\n")
        amp_screen1(outport)
        input("Step to amp edit screen 2 and hit ENTER...\n")
        amp_screen2(outport, control_rec[2])

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

###################### main ########################

args = sys.argv

if len(args) < 4:
    print("Usage: test.py <controller_port> <midi_channel> <v1|v2> [test_name]\n")
    print("Pass test name in {pc, tuner, efxbypass, stomp, mod, reverb, delay, amp} for single test\n")
    print("Default is to run all of them if no arg 4 passed\n")
    sys.exit(1)

try:
    pc.channel = cc.channel = int(args[2]) - 1
except ValueError:
    print("Arg2 must be numeric!\n")
    sys.exit(1)

if args[3] == "v1":
    type = 1
elif args[3] == "v2":
    type = 2
else:
    print("Arg 3 must be 'v1' or 'v2'")
    sys.exit(1)

single = "all"
if len(args) == 5:
    single = args[4]

outport = mido.open_output(args[1])

if single == "all" or single == "pc":
    program_change_test(outport)

if single == "all" or single == "tuner":
    tuner_test(outport)

if single == "all" or single == "efxbypass":
    bypass_test(outport)

print("All tests complete\n")
