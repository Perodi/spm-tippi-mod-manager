-include tasks/Makefile.*

# Try to set DEVKITPPC to the default install location if it's not defined
DEVKITPPC ?= /opt/devkitpro/devkitPPC

# Add the DEVKITPPC bin directory to PATH
export PATH := $(PATH):$(DEVKITPPC)/bin

# For notes on PowerPC specific options see:
# https://gcc.gnu.org/onlinedocs/gcc/RS_002f6000-and-PowerPC-Options.html
#
# NOTE: -mrvl is devkitPPC specific and doesn't appear to have specific documentation
MACHINE_OPTIONS = -mrvl -mcpu=750 -meabi -mhard-float

INCLUDE_DIRS = include external/spm-headers/include
INCLUDES = $(addprefix -I,$(INCLUDE_DIRS))

ASSEMBLER = powerpc-eabi-as
LINKER = powerpc-eabi-ld

CPP_COMPILER = powerpc-eabi-g++
CPP_FLAGS = $(MACHINE_OPTIONS) -std=gnu++23 -Wall -fno-rtti -Wl,--gc-sections
CPP_COMPILE = $(CPP_COMPILER) $(CPP_FLAGS) $(INCLUDES)

build:
	mkdir $@
	touch $@

build/spm: build
	mkdir $@
	touch $@