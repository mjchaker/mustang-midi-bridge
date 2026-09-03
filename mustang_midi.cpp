// mustang_midi: translate MIDI messages into the Fender Mustang USB protocol.
//
// Usage: mustang_midi <controller_port#> <midi_channel#>
//        mustang_midi <virtual_port_name> <midi_channel#>
//
// The first argument is either a numeric RtMidi input port index or,
// if it is not a number, the name of a virtual input port to create.

#include <cstdlib>
#include <cstdio>
#include <csignal>
#include <cerrno>
#include <memory>
#include <RtMidi.h>

#include "mustang.h"
#include "midi_cc.h"

// If you see a compiler error complaining about a missing 
// symbol 'RtMidiError' you probably have an old version of
// of the library and will need to build with this flag:
// $ make CPPFLAGS=-DRTMIDI_2_0
//

#ifdef RTMIDI_2_0
# define RT_ERROR RtError
#else 
# define RT_ERROR RtMidiError
#endif

static Mustang mustang;

// Zero-based MIDI channel we listen on
static int channel;

// Set by the signal handler to request an orderly shutdown
static volatile sig_atomic_t shutdown_requested = 0;

static void request_shutdown( int ) {
  shutdown_requested = 1;
}


// Route a control change to the Mustang method responsible for it.
// Returns 0 on success, nonzero on USB failure.
static int dispatch_cc( int cc, int value ) {
  if ( cc == CC_TUNER )                                 return mustang.tunerMode( value );

  if ( cc == CC_ALL_EFX_BYPASS ) {
    // Apply the same on/off state to every effect family
    for ( int fx = CC_STOMP_BYPASS; fx <= CC_REVERB_BYPASS; fx++ ) {
      int rc = mustang.effectToggle( fx, value );
      if ( rc ) return rc;
    }
    return 0;
  }
  if ( cc >= CC_STOMP_BYPASS && cc <= CC_REVERB_BYPASS ) return mustang.effectToggle( cc, value );

  if ( cc == CC_STOMP_MODEL )                           return mustang.setStomp( value );
  if ( cc >= CC_STOMP_PARM_LO && cc <= CC_STOMP_PARM_HI )   return mustang.stompControl( cc, value );

  if ( cc == CC_MOD_MODEL )                             return mustang.setMod( value );
  if ( cc >= CC_MOD_PARM_LO && cc <= CC_MOD_PARM_HI )       return mustang.modControl( cc, value );

  if ( cc == CC_DELAY_MODEL )                           return mustang.setDelay( value );
  if ( cc >= CC_DELAY_PARM_LO && cc <= CC_DELAY_PARM_HI )   return mustang.delayControl( cc, value );

  if ( cc == CC_REVERB_MODEL )                          return mustang.setReverb( value );
  if ( cc >= CC_REVERB_PARM_LO && cc <= CC_REVERB_PARM_HI ) return mustang.reverbControl( cc, value );

  if ( cc == CC_AMP_MODEL )                             return mustang.setAmp( value );
  if ( cc >= CC_AMP_PARM_LO && cc <= CC_AMP_PARM_HI )       return mustang.ampControl( cc, value );

  // Unassigned controller: ignore
  return 0;
}


void message_action( double /*deltatime*/, std::vector< unsigned char > *message, void * /*userData*/ ) {
  if ( message == NULL || message->empty() ) return;

#if 0
  unsigned int nBytes = message->size();
  if      ( nBytes == 2 ) fprintf( stdout, "%02x %d\n", (int)message->at(0), (int)message->at(1) );
  else if ( nBytes == 3 ) fprintf( stdout, "%02x %d %d\n", (int)message->at(0), (int)message->at(1), (int)message->at(2) );
#endif

  const unsigned char status = (*message)[0];

  // Is this for us?
  int msg_channel = status & 0x0f;
  if ( msg_channel != channel ) return;

  int msg_type = status & 0xf0;

  switch ( msg_type ) {

  case 0xc0: {
    // Program change: one data byte
    if ( message->size() < 2 ) return;
    int program = (*message)[1];
    int rc = mustang.patchChange( program );
    if ( rc ) {
      fprintf( stderr, "Error: PC#%d failed. RC = %d\n", program, rc );
    }
  }
  break;
    
  case 0xb0: {
    // Control change: two data bytes
    if ( message->size() < 3 ) return;
    int cc = (*message)[1];
    int value = (*message)[2];
    int rc = dispatch_cc( cc, value );
    if ( rc ) {
      fprintf( stderr, "Error: CC#%d failed. RC = %d\n", cc, rc );
    }
  }
  break;

  default:
    break;
  }

}


static void usage() {
  fputs( "Usage: mustang_midi <controller_port#> <midi_channel#>\n"
         "       mustang_midi <virtual_port> <midi_channel#>\n\n"
         "       port = 0..n,  channel = 1..16\n", stderr );
  exit( 1 );
}


int main( int argc, const char **argv ) {
  if ( argc != 3 ) usage();

  // Parse the channel first so a bad value is reported before we
  // touch any MIDI or USB resources.
  char *endptr;
  long chan_arg = strtol( argv[2], &endptr, 10 );
  if ( *argv[2] == '\0' || *endptr != '\0' ) usage();
  if ( chan_arg < 1 || chan_arg > 16 ) usage();
  channel = (int)chan_arg - 1;

  // Shut down cleanly on SIGINT / SIGTERM / SIGHUP so the USB interface
  // is released and the kernel driver reattached.  The signals are
  // blocked here, before RtMidi and the USB listener spawn their
  // threads (which inherit the mask), and are atomically unblocked
  // only inside sigsuspend() on the main thread, so a signal can
  // never be lost or delivered to a thread that is not waiting for it.
  struct sigaction sa;
  memset( &sa, 0, sizeof(sa) );
  sa.sa_handler = request_shutdown;
  sigemptyset( &sa.sa_mask );
  sigaction( SIGINT, &sa, NULL );
  sigaction( SIGTERM, &sa, NULL );
  sigaction( SIGHUP, &sa, NULL );

  sigset_t block_set, wait_set;
  sigemptyset( &block_set );
  sigaddset( &block_set, SIGINT );
  sigaddset( &block_set, SIGTERM );
  sigaddset( &block_set, SIGHUP );
  sigprocmask( SIG_BLOCK, &block_set, &wait_set );

  // RtMidiIn's constructor itself throws when no MIDI backend is
  // usable (e.g. no ALSA sequencer), so construct it inside the try.
  std::unique_ptr<RtMidiIn> input_handler;

  long port = strtol( argv[1], &endptr, 10 );
  bool numeric_port = ( *argv[1] != '\0' && *endptr == '\0' );

  try {
    input_handler.reset( new RtMidiIn() );

    if ( numeric_port ) {
      unsigned int port_count = input_handler->getPortCount();
      if ( port < 0 || (unsigned long)port >= port_count ) {
        fprintf( stderr, "MIDI input port %ld does not exist (%u ports available)\n",
                 port, port_count );
        exit( 1 );
      }
      input_handler->openPort( (unsigned int)port );
    }
    else {
      input_handler->openVirtualPort( argv[1] );
    }

    input_handler->setCallback( &message_action );

    // Don't want sysex, timing, active sense
    input_handler->ignoreTypes( true, true, true );
  }
  catch ( RT_ERROR &error ) {
    fprintf( stderr, "Cannot open MIDI port '%s': %s\n", argv[1], error.getMessage().c_str() );
    exit( 1 );
  }

  if ( 0 != mustang.initialize() ) {
    fprintf( stderr, "Cannot setup USB communication\n" );
    exit( 1 );
  }
  if ( 0 != mustang.commStart() ) {
    fprintf( stderr, "Thread setup and init failed\n" );
    mustang.deinitialize();
    exit( 1 );
  }

  // Block until a shutdown signal arrives
  while ( !shutdown_requested ) sigsuspend( &wait_set );

  sigprocmask( SIG_SETMASK, &wait_set, NULL );

  input_handler->cancelCallback();
  input_handler->closePort();

  int status = 0;
  if ( 0 != mustang.commShutdown() ) {
    fprintf( stderr, "Thread shutdown failed\n" );
    status = 1;
  }
  if ( 0 != mustang.deinitialize() ) {
    fprintf( stderr, "USB shutdown failed\n" );
    status = 1;
  }
  
  return status;
}
