
# Newer distributions put rtmidi headers in subdirectory
RTMIDI_INC := $(shell ls -d /usr/include/rtmidi 2>/dev/null | tail -n 1)
ifneq (,$(RTMIDI_INC))
  INCDIRS = -I/usr/include/rtmidi
endif

# Check for Homebrew libusb on macOS
BREW_LIBUSB := $(shell ls -d /opt/homebrew/Cellar/libusb/*/include 2>/dev/null | tail -n 1)
ifneq (,$(BREW_LIBUSB))
  INCDIRS += -I$(BREW_LIBUSB)
endif

# Check for Homebrew rtmidi on macOS
BREW_RTMIDI := $(shell ls -d /opt/homebrew/Cellar/rtmidi/*/include 2>/dev/null | tail -n 1)
ifneq (,$(BREW_RTMIDI))
  INCDIRS += -I$(BREW_RTMIDI) -I$(BREW_RTMIDI)/rtmidi
endif

SRC = $(wildcard *.cpp)
OBJ = $(subst .cpp,.o,$(SRC))
DEP = $(subst .cpp,.d,$(SRC))

# The -M* switches automatically generate .d dependency files
CPPFLAGS += -MP -MMD $(INCDIRS)

# Use C++11 standard for modern features
CXXFLAGS += -std=c++11

# Check for Homebrew lib paths on macOS
BREW_LIBUSB_LIB := $(shell ls -d /opt/homebrew/Cellar/libusb/*/lib 2>/dev/null | tail -n 1)
BREW_RTMIDI_LIB := $(shell ls -d /opt/homebrew/Cellar/rtmidi/*/lib 2>/dev/null | tail -n 1)

BREW_LIBUSB_LIBFILE := $(shell find $(BREW_LIBUSB_LIB) -name "libusb-1.0.dylib" 2>/dev/null | tail -n 1)
BREW_RTMIDI_LIBFILE := $(shell find $(BREW_RTMIDI_LIB) -name "librtmidi.dylib" 2>/dev/null | tail -n 1)

ifeq ($(shell uname -s),Darwin)
  # On macOS, use exact paths to dylib files for linking
  ifneq (,$(BREW_LIBUSB_LIBFILE))
    LDLIBS += $(BREW_LIBUSB_LIBFILE)
  else
    LDLIBS += -lusb-1.0
  endif

  ifneq (,$(BREW_RTMIDI_LIBFILE))
    LDLIBS += $(BREW_RTMIDI_LIBFILE)
  else
    LDLIBS += -lrtmidi
  endif
else
  # On Linux, use standard library flags
  LDLIBS = -lrtmidi -lusb-1.0
endif

# Common libraries
LDLIBS += -lpthread

BIN = mustang_midi

opt: CXXFLAGS += -O3 -DNDEBUG
opt: $(BIN)

debug: CXXFLAGS += -g -DDEBUG
debug: $(BIN)

$(BIN): $(OBJ)
	$(CXX) $^ -o $@ $(LDLIBS)

clean: 
	rm -f $(DEP) $(OBJ) $(BIN) *~

-include $(SRC:.cpp=.d)

