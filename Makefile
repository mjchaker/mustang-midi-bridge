# Check for Homebrew libusb on macOS M1
HOMEBREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo "/opt/homebrew")
BREW_LIBUSB := $(shell ls -d $(HOMEBREW_PREFIX)/Cellar/libusb/*/include 2>/dev/null | head -n 1)
BREW_RTMIDI := $(shell ls -d $(HOMEBREW_PREFIX)/Cellar/rtmidi/*/include 2>/dev/null | head -n 1)

# Include directories
INCDIRS = 
ifneq (,$(BREW_RTMIDI))
  INCDIRS += -I$(BREW_RTMIDI) -I$(BREW_RTMIDI)/rtmidi
endif
ifneq (,$(BREW_LIBUSB))
  INCDIRS += -I$(BREW_LIBUSB)
endif

SRC = $(wildcard *.cpp)
OBJ = $(subst .cpp,.o,$(SRC))
DEP = $(subst .cpp,.d,$(SRC))

# The -M* switches automatically generate .d dependency files
CPPFLAGS += -MP -MMD $(INCDIRS)

# Use C++11 standard for modern features and add architecture for M1
CXXFLAGS += -std=c++11 -arch arm64

# Homebrew library paths on macOS
BREW_LIBUSB_LIB := $(shell ls -d $(HOMEBREW_PREFIX)/Cellar/libusb/*/lib 2>/dev/null | head -n 1)
BREW_RTMIDI_LIB := $(shell ls -d $(HOMEBREW_PREFIX)/Cellar/rtmidi/*/lib 2>/dev/null | head -n 1)

# Find actual library files
BREW_LIBUSB_LIBFILE := $(shell find $(BREW_LIBUSB_LIB) -name "libusb-1.0.dylib" 2>/dev/null | head -n 1)
BREW_RTMIDI_LIBFILE := $(shell find $(BREW_RTMIDI_LIB) -name "librtmidi.dylib" 2>/dev/null | head -n 1)

# On macOS, use exact paths to dylib files for linking
LDLIBS =
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