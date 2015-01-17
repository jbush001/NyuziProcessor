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

# This file is included in the sub makefiles

WORKDIR=WORK
TOPDIR=../../../
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
CFLAGS=-g -Wall -W -O3 -fno-rtti -std=c++11 -I$(TOPDIR)/software/libc/include -I$(TOPDIR)/software/librender -I$(TOPDIR)/software/libos
BASE_ADDRESS=0
LIBS=$(TOPDIR)/software/librender/librender.a $(TOPDIR)/software/libc/libc.a $(TOPDIR)/software/libos/libos.a

OBJS := $(SRCS:%.cpp=$(WORKDIR)/%.o)
DEPS := $(SRCS:%.cpp=$(WORKDIR)/%.d)

$(WORKDIR)/program.hex: $(WORKDIR)/program.elf
	$(ELF2HEX) -b $(BASE_ADDRESS) -o $@ $<
	
$(WORKDIR)/program.elf: $(DEPS) $(OBJS) 
	$(LD) -Ttext=$(BASE_ADDRESS) -o $@ $(TOPDIR)/software/libos/crt0.o $(OBJS) $(LIBS)

program.lst: $(WORKDIR)/program.elf
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
run: $(WORKDIR)/program.hex
	rm -f $(WORKDIR)/output.bin output.png
	$(EMULATOR) -d $(WORKDIR)/output.bin,200000,12C000 $(WORKDIR)/program.hex
	convert -depth 8 -size 640x480 rgba:$(WORKDIR)/output.bin output.png

# Run in emulator under debugger
debug: $(WORKDIR)/program.hex
	$(EMULATOR) -m gdb $(WORKDIR)/program.hex &
	$(COMPILER_DIR)/lldb --arch nyuzi $(WORKDIR)/program.elf -o "gdb-remote 8000" 

# Run in verilator
verirun: $(WORKDIR)/program.hex
	rm -f $(WORKDIR)/output.bin output.png
	$(VERILATOR) +memdumpfile=$(WORKDIR)/output.bin +memdumpbase=200000 +memdumplen=12C000 +bin=$(WORKDIR)/program.hex
	convert -depth 8 -size 640x480 rgba:$(WORKDIR)/output.bin output.png

-include $(DEPS)

