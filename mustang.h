// -*-c++-*-
//
// Mustang: owns the USB connection to a Fender Mustang amplifier and
// translates high-level requests (patch change, model select, parameter
// edit, ...) into the 64-byte packet protocol described in
// doc/fender_mustang_protocol.txt.
//
// Threading model: a background listener thread (handleInput) reads
// every packet the amp sends.  Command methods write a packet and then
// block on a Condition until the listener observes the matching
// acknowledgement, or ACK_TIMEOUT_MS elapses.

#ifndef MUSTANG2_H
#define MUSTANG2_H

#include <stdint.h>
#include <cstring>
#include <libusb.h>
#include <pthread.h>
#include "constants.h"

#define USB_IN  0x81
#define USB_OUT 0x01

// Per-transfer USB timeout
#define USB_TIMEOUT_MS 500

// How long a command waits for the amp to acknowledge it
#define ACK_TIMEOUT_MS 2000

// A full parameter dump (124 preset names + DSP state) takes longer
#define DUMP_TIMEOUT_MS 10000

// Number of preset name slots: 0-99 amp, 100-111 mod, 112-123 rev/delay
#define NUM_PRESET_NAMES 124

class AmpCC;
class ReverbCC;
class DelayCC;
class ModCC;
class StompCC;


class Mustang {

  // Pre-built 'execute' command
  unsigned char execute[64];
  
  libusb_device_handle *usb_io;

  // True if we detached a kernel driver in initialize() and must
  // reattach it in deinitialize()
  bool kernel_driver_detached;

  // USB listen thread
  pthread_t worker;
  bool worker_running;

  // Shutdown request flag
  pthread_mutex_t shutdown_lock;
  bool want_shutdown;

  // A flag guarded by a mutex, with a condition variable to wait on
  template <class T>
  class Condition {
  public:
    pthread_mutex_t lock;
    pthread_cond_t cond;
    T value;
    Condition( void ) : value() {
      pthread_mutex_init( &lock, NULL );
      pthread_cond_init( &cond, NULL );
    }
    ~Condition( void ) {
      pthread_cond_destroy( &cond );
      pthread_mutex_destroy( &lock );
    }
  private:
    Condition( const Condition & );
    Condition & operator=( const Condition & );
  };

  // Wait (with sync.lock already held) until sync.value == target.
  // Returns 0 on success or LIBUSB_ERROR_TIMEOUT if the amp never
  // answered within timeout_ms.
  static int awaitFlag( Condition<bool> &sync, bool target, int timeout_ms = ACK_TIMEOUT_MS );

  // Identify patch-change ack / DSP parm update
  static const unsigned char state_prefix[];

  // Received {0x1c, 0x01, 0x00, ...}
  // --> End of preset select acknowledge stream
  Condition<bool> pc_ack_sync;

  // Synchronize access to preset names
  Condition<bool> preset_names_sync;

  // 0-99 = amp preset, 100-111 = mod preset, 112-123 = rev/delay preset
  char preset_names[NUM_PRESET_NAMES][33];

  // Index to current amp preset 
  unsigned curr_preset_idx;

  // Manage access to each DSP data block and/or associated object.
  Condition<bool> dsp_sync[6];
  unsigned char dsp_parms[6][64];

  // Manage data and behavior for specific DSP models.  NULL until the
  // first state report for that DSP has been received.
  AmpCC * curr_amp;
  StompCC * curr_stomp;
  ModCC * curr_mod;
  DelayCC * curr_delay;
  ReverbCC * curr_reverb;

  // Synchronize on end of parm dump
  Condition<bool> parm_read_sync;
  static const unsigned char parm_read_ack[];

  // Synchronize on receipt of direct control acknowledge
  Condition<bool> cc_ack_sync;
  static const unsigned char cc_ack[];

  // Received {0x00, 0x00, 0x19, ... }
  // --> Acknowledge efx on/off toggle
  Condition<bool> efx_toggle_sync;
  static const unsigned char efx_toggle_ack[];

  // Synchronize on receipt of model change acknowledge
  Condition<bool> model_change_sync;
  static const unsigned char model_change_ack[];

  // Sync on tuner on/off ack.  value == true while the tuner is engaged.
  Condition<bool> tuner_ack_sync;
  static const unsigned char tuner_ack[];
  
  // Attached device probe structure
  struct usb_id {
    // product id
    int pid;
    // magic value for init packet
    int init_value;
    // v2?
    bool isV2;
  };

  static const usb_id amp_ids[];
  bool isV2;

  static void *threadStarter( void * );
  void handleInput( void );

  int direct_control( unsigned char *cmd );
  
  int sendCmd( unsigned char *buffer );
  int drainReply( void );
  int initFailed( int rc );
  int requestDump( void );
  int executeModelChange( unsigned char *buffer );

  void updateAmpObj( const unsigned char *data );
  void updateStompObj( const unsigned char *data );
  void updateReverbObj( const unsigned char *data );
  void updateDelayObj( const unsigned char *data );
  void updateModObj( const unsigned char *data );

  int checkOrDisableTuner( void );

  // Check for equality of 2-byte values
  inline bool match16( const unsigned char *a, const unsigned char *b ) const {
    return ( 0==memcmp(a,b,2) );
  }

  Mustang( const Mustang & );
  Mustang & operator=( const Mustang & );

public:
  Mustang( void );
  ~Mustang( void );

  // Locate the amp on USB and run the init handshake.  0 on success.
  int initialize( void );
  int deinitialize( void );
  
  // Start the listener thread and load current state from the amp.
  int commStart( void );
  int commShutdown( void );

  // Model select by ordinal (0 = none).  Unknown ordinals are ignored.
  int setAmp( int ord );
  int ampControl( int cc, int value );

  int setStomp( int ord );
  int stompControl( int cc, int value );

  int setMod( int ord );
  int modControl( int cc, int value );

  int setDelay( int ord );
  int delayControl( int cc, int value );

  int setReverb( int ord );
  int reverbControl( int cc, int value );

  // >63 engages the tuner, <=63 releases it
  int tunerMode( int value );
    
  // Select amp preset 0..99
  int patchChange( int patch );

  // cc 23..26 = stomp/mod/delay/reverb; >63 on, <=63 off
  int effectToggle( int cc, int value );
};


#endif
