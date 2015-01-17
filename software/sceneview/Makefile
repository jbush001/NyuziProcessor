# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 

MODEL_FILE=dabrovik_sponza/sponza.obj
FB_WIDTH=800
FB_HEIGHT=600
MEMORY_SIZE=8000000

WORKDIR=WORK
TOPDIR=../../
BINDIR=$(TOPDIR)/bin
LOCAL_TOOL_DIR=$(TOPDIR)/tools
COMPILER_DIR=/usr/local/llvm-nyuzi/bin
CC=$(COMPILER_DIR)/clang
LD=$(COMPILER_DIR)/ld.mcld
ELF2HEX=$(COMPILER_DIR)/elf2hex
OBJDUMP=$(COMPILER_DIR)/llvm-objdump
PROFILER=$(LOCAL_TOOL_DIR)/misc/profile.py
EMULATOR=$(BINDIR)/emulator
VERILATOR=$(BINDIR)/verilator_model
CFLAGS=-g -Wall -W -O3 -fno-rtti -std=c++11 -I$(TOPDIR)/software/libc/include -I$(TOPDIR)/software/librender -I$(TOPDIR)/software/libos -DFB_WIDTH=$(FB_WIDTH) -DFB_HEIGHT=$(FB_HEIGHT)
BASE_ADDRESS=0
LIBS=$(TOPDIR)/software/librender/librender.a $(TOPDIR)/software/libc/libc.a $(TOPDIR)/software/libos/libos.a

SRCS=viewobj.cpp

OBJS := $(SRCS:%.cpp=$(WORKDIR)/%.o)
DEPS := $(SRCS:%.cpp=$(WORKDIR)/%.d)

all: $(WORKDIR)/program.hex resource.bin

$(WORKDIR)/program.hex: $(WORKDIR)/program.elf
	$(ELF2HEX) -b $(BASE_ADDRESS) -o $@ $<
	
$(WORKDIR)/program.elf: $(DEPS) $(OBJS) 
	$(LD) -Ttext=$(BASE_ADDRESS) -o $@ $(TOPDIR)/software/libos/crt0.o $(OBJS) $(LIBS)

program.lst: $(WORKDIR)/program.elf FORCE
	$(OBJDUMP) --disassemble WORK/program.elf > program.lst 2> /dev/null	# Make disassembly file

$(WORKDIR)/%.o : %.cpp 
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS) -o $@ -c $<

$(WORKDIR)/%.o : %.s
	@echo "Assembling $<..."
	@$(CC) -o $@ -c $<

$(WORKDIR)/%.d: %.cpp
	@echo "Building dependencies for $<..."
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -o $(WORKDIR)/$*.d -MM $<

clean:
	rm -rf $(WORKDIR)

# Run in emulator
run: $(WORKDIR)/program.hex resource.bin
	rm -f $(WORKDIR)/output.bin output.png
	$(EMULATOR) -t 32 -c $(MEMORY_SIZE) -f $(FB_WIDTH)x$(FB_HEIGHT) -b resource.bin $(WORKDIR)/program.hex

# Run in emulator under debugger
debug: $(WORKDIR)/program.hex resource.bin
	$(EMULATOR) -m gdb -c $(MEMORY_SIZE) -f $(FB_WIDTH)x$(FB_HEIGHT) -b resource.bin $(WORKDIR)/program.hex &
	$(COMPILER_DIR)/lldb --arch nyuzi $(WORKDIR)/program.elf -o "gdb-remote 8000" 

resource.bin: 
	./make_resource_file.py $(MODEL_FILE)

FORCE:

-include $(DEPS)

