# mustang_midi build
#
# Works on Linux (apt: librtmidi-dev libusb-1.0-0-dev) and on macOS with
# Homebrew (brew install rtmidi libusb pkg-config).  Library locations are
# discovered through pkg-config when it is available; otherwise we fall back
# to the conventional system paths.
#
# Targets:  make (or make opt)  optimized build
#           make debug           -g plus DEBUG tracing of USB traffic
#           make test            build and run the hardware-free unit tests
#           make clean
#
# Old rtmidi (RtError instead of RtMidiError):  make CPPFLAGS=-DRTMIDI_2_0

BIN      = mustang_midi
TEST_BIN = test_dispatch

SRC = $(wildcard *.cpp)
OBJ = $(SRC:.cpp=.o)
DEP = $(SRC:.cpp=.d)

# Objects shared with the unit test: everything except main()
LIB_OBJ = $(filter-out mustang_midi.o,$(OBJ))

PKG_CONFIG ?= pkg-config
PKG_OK := $(shell $(PKG_CONFIG) --exists rtmidi libusb-1.0 2>/dev/null && echo yes)

ifeq ($(PKG_OK),yes)
  PKG_CFLAGS := $(shell $(PKG_CONFIG) --cflags rtmidi libusb-1.0)
  PKG_LIBS   := $(shell $(PKG_CONFIG) --libs rtmidi libusb-1.0)
else
  # Fallback: newer distributions put the rtmidi header in a subdirectory
  PKG_CFLAGS := -I/usr/include/rtmidi -I/usr/include/libusb-1.0
  ifeq ($(shell uname -s),Darwin)
    HOMEBREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo /opt/homebrew)
    PKG_CFLAGS += -I$(HOMEBREW_PREFIX)/include -I$(HOMEBREW_PREFIX)/include/rtmidi -I$(HOMEBREW_PREFIX)/include/libusb-1.0
    PKG_LIBS   := -L$(HOMEBREW_PREFIX)/lib
  endif
  PKG_LIBS += -lrtmidi -lusb-1.0
endif

# The -M* switches automatically generate .d dependency files
CPPFLAGS += -MP -MMD $(PKG_CFLAGS)
CXXFLAGS += -std=c++11 -Wall -Wextra
LDLIBS   += $(PKG_LIBS) -lpthread

.PHONY: all opt debug test clean

all: opt

opt: CXXFLAGS += -O3 -DNDEBUG
opt: $(BIN)

debug: CXXFLAGS += -g -DDEBUG
debug: $(BIN)

$(BIN): $(OBJ)
	$(CXX) $^ -o $@ $(LDLIBS)

# Unit tests exercise the CC -> USB byte-layout logic; no amp required.
$(TEST_BIN): tests/test_dispatch.cpp $(LIB_OBJ)
	$(CXX) $(PKG_CFLAGS) $(CXXFLAGS) -I. $^ -o $@ $(LDLIBS)

test: $(TEST_BIN)
	./$(TEST_BIN)

clean:
	rm -f $(DEP) $(OBJ) $(BIN) $(TEST_BIN) *~

-include $(DEP)
