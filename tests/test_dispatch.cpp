// Hardware-free unit tests for the CC -> USB packet layout logic.
//
// The per-DSP handler classes (AmpCC, StompCC, ...) are pure functions
// from (controller, value) to a 64-byte command image; they only hold a
// Mustang pointer that they never dereference.  That makes them
// testable without an amplifier: build a handler, dispatch a CC, and
// inspect the bytes it produced.
//
// Build and run with:  make test

#include <cstdio>
#include <cstring>

#include "amp.h"
#include "amp_models.h"
#include "stomp.h"
#include "stomp_models.h"
#include "mod.h"
#include "mod_models.h"
#include "delay.h"
#include "delay_models.h"
#include "reverb.h"
#include "reverb_models.h"
#include "magic.h"
#include "constants.h"

static int failures = 0;
static int checks = 0;

#define CHECK(cond)                                                     \
  do {                                                                  \
    checks++;                                                           \
    if ( !(cond) ) {                                                    \
      failures++;                                                       \
      fprintf( stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond ); \
    }                                                                   \
  } while ( 0 )

static void clear( unsigned char *cmd ) { memset( cmd, 0, 64 ); }

// Every continuous control encodes the 7-bit MIDI value through the
// same 128-entry lookup table into a 16-bit little-endian word at
// bytes 9..10.  Check the table itself, then the placement.
static void test_magic_table( void ) {
  CHECK( magic_values[0] == 0x0000 );
  CHECK( magic_values[127] == 0xffff );
  CHECK( magic_values[64] == 0x8083 );
  for ( int i = 1; i < 128; i++ ) CHECK( magic_values[i] > magic_values[i-1] );
}

static void test_amp_continuous( void ) {
  unsigned char cmd[64];
  AmpCC amp( NULL, f57_deluxe_id, 0 );

  clear( cmd );
  CHECK( amp.dispatch( 69, 127, cmd ) == 0 );   // Gain
  CHECK( cmd[2] == 0x02 );                       // amp DSP family
  CHECK( cmd[3] == f57_deluxe_id[0] && cmd[4] == f57_deluxe_id[1] );
  CHECK( cmd[5] == 0x01 && cmd[6] == 0x01 && cmd[7] == 0x0c );
  CHECK( cmd[9] == 0xff && cmd[10] == 0xff );

  clear( cmd );
  CHECK( amp.dispatch( 70, 64, cmd ) == 0 );    // Volume
  CHECK( cmd[5] == 0x00 && cmd[6] == 0x00 );
  CHECK( cmd[9] == 0x83 && cmd[10] == 0x80 );   // 0x8083 little-endian

  clear( cmd );
  CHECK( amp.dispatch( 73, 0, cmd ) == 0 );     // Bass
  CHECK( cmd[9] == 0x00 && cmd[10] == 0x00 );
}

static void test_amp_discrete_and_ranges( void ) {
  unsigned char cmd[64];
  AmpCC amp( NULL, f57_deluxe_id, 0 );

  clear( cmd );
  CHECK( amp.dispatch( 74, 2, cmd ) == 0 );     // Sag: 0..2 valid
  CHECK( cmd[5] == 0x13 && cmd[7] == 0x8f && cmd[9] == 2 );
  CHECK( amp.dispatch( 74, 3, cmd ) < 0 );      // out of range -> ignored

  CHECK( amp.dispatch( 77, 12, cmd ) == 0 );    // Cabinet 0..12
  CHECK( amp.dispatch( 77, 13, cmd ) < 0 );

  CHECK( amp.dispatch( 68, 1, cmd ) < 0 );      // not an amp parameter CC
  CHECK( amp.dispatch( 80, 1, cmd ) < 0 );
}

// Subclasses override only the controls that differ between models.
static void test_amp_model_variants( void ) {
  unsigned char cmd[64];

  AmpCC base( NULL, f57_deluxe_id, 0 );
  CHECK( base.dispatch( 78, 10, cmd ) < 0 );    // no presence on F57 Deluxe
  CHECK( base.dispatch( 79, 10, cmd ) < 0 );

  AmpCC4 brit80( NULL, brit_80s_id, 0 );
  clear( cmd );
  CHECK( brit80.dispatch( 78, 10, cmd ) == 0 ); // Presence
  CHECK( cmd[5] == 0x07 && cmd[3] == brit_80s_id[0] );
  clear( cmd );
  CHECK( brit80.dispatch( 79, 10, cmd ) == 0 ); // Master volume
  CHECK( cmd[5] == 0x03 );

  AmpCC5 preamp( NULL, studio_preamp_id, 0 );
  CHECK( preamp.dispatch( 74, 1, cmd ) < 0 );   // no sag on Studio Preamp
  CHECK( preamp.dispatch( 69, 1, cmd ) == 0 );  // but gain still works

  // Virtual dispatch must work through the base pointer that Mustang holds
  AmpCC *p = new NullAmpCC( NULL, null_amp_id, 0 );
  CHECK( p->dispatch( 69, 100, cmd ) < 0 );
  delete p;
}

static void test_stomp( void ) {
  unsigned char cmd[64];
  StompCC *p = new OverdriveCC( NULL, overdrive_id, 3 );
  CHECK( p->getSlot() == 3 );

  clear( cmd );
  CHECK( p->dispatch( 29, 127, cmd ) == 0 );
  CHECK( cmd[2] == 0x03 );                       // stomp DSP family
  CHECK( cmd[3] == overdrive_id[0] && cmd[4] == overdrive_id[1] );
  CHECK( cmd[9] == 0xff && cmd[10] == 0xff );

  CHECK( p->dispatch( 34, 1, cmd ) < 0 );        // outside 29..33
  delete p;

  p = new NullStompCC( NULL, null_stomp_id, 0 );
  CHECK( p->dispatch( 29, 100, cmd ) < 0 );
  delete p;
}

static void test_mod_delay( void ) {
  unsigned char cmd[64];

  ModCC *m = new ChorusCC( NULL, sine_chorus_id, 1 );
  clear( cmd );
  CHECK( m->dispatch( 39, 1, cmd ) == 0 );
  CHECK( cmd[2] == 0x04 );                       // mod DSP family
  CHECK( m->dispatch( 44, 1, cmd ) < 0 );
  delete m;

  DelayCC *d = new MonoDelayCC( NULL, mono_dly_id, 2 );
  clear( cmd );
  CHECK( d->dispatch( 49, 1, cmd ) == 0 );
  CHECK( cmd[2] == 0x05 );                       // delay DSP family
  CHECK( d->dispatch( 55, 1, cmd ) < 0 );
  delete d;
}

static void test_reverb( void ) {
  unsigned char cmd[64];
  const unsigned char hall[2] = { SM_HALL_ID & 0xff, SM_HALL_ID >> 8 };

  ReverbCC *r = new ReverbCC( NULL, hall, 4 );
  clear( cmd );
  CHECK( r->dispatch( 59, 96, cmd ) == 0 );      // Level
  CHECK( cmd[2] == 0x06 );                       // reverb DSP family
  CHECK( cmd[5] == 0x00 && cmd[7] == 0x0b );
  CHECK( cmd[9] == (magic_values[96] & 0xff) && cmd[10] == (magic_values[96] >> 8) );
  CHECK( r->dispatch( 58, 1, cmd ) < 0 );
  CHECK( r->dispatch( 64, 1, cmd ) < 0 );
  delete r;

  // "No reverb" must swallow parameter edits even via the base pointer
  r = new NullReverbCC( NULL, null_reverb_id, 0 );
  clear( cmd );
  CHECK( r->dispatch( 59, 96, cmd ) < 0 );
  CHECK( cmd[2] == 0x00 );                       // nothing written
  delete r;
}

int main( void ) {
  test_magic_table();
  test_amp_continuous();
  test_amp_discrete_and_ranges();
  test_amp_model_variants();
  test_stomp();
  test_mod_delay();
  test_reverb();

  if ( failures ) {
    fprintf( stderr, "%d of %d checks FAILED\n", failures, checks );
    return 1;
  }
  printf( "All %d checks passed\n", checks );
  return 0;
}
