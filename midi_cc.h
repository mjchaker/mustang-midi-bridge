// -*-c++-*-
//
// MIDI controller numbers understood by the bridge.  This is the
// Fender Mustang Floor / MIDX-20 assignment (see doc/MIDX20_Midi_Spec.pdf).
// Program Change 0..99 selects an amp preset.

#ifndef MIDI_CC_H
#define MIDI_CC_H

enum MidiCC {
  CC_TUNER          = 20,   // >63 on, <=63 off

  CC_ALL_EFX_BYPASS = 22,   // >63 all effects on, <=63 all off
  CC_STOMP_BYPASS   = 23,
  CC_MOD_BYPASS     = 24,
  CC_DELAY_BYPASS   = 25,
  CC_REVERB_BYPASS  = 26,

  CC_STOMP_MODEL    = 28,   // value = model ordinal, 0 = none
  CC_STOMP_PARM_LO  = 29,
  CC_STOMP_PARM_HI  = 33,

  CC_MOD_MODEL      = 38,
  CC_MOD_PARM_LO    = 39,
  CC_MOD_PARM_HI    = 43,

  CC_DELAY_MODEL    = 48,
  CC_DELAY_PARM_LO  = 49,
  CC_DELAY_PARM_HI  = 54,

  CC_REVERB_MODEL   = 58,
  CC_REVERB_PARM_LO = 59,
  CC_REVERB_PARM_HI = 63,

  CC_AMP_MODEL      = 68,
  CC_AMP_PARM_LO    = 69,
  CC_AMP_PARM_HI    = 79
};

#endif
