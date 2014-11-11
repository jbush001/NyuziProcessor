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

WORKDIR=WORK
BINDIR=../../bin
LOCAL_TOOL_DIR=../../tools
COMPILER_DIR=/usr/local/llvm-nyuzi/bin
CC=$(COMPILER_DIR)/clang
LD=$(COMPILER_DIR)/ld.mcld
ELF2HEX=$(COMPILER_DIR)/elf2hex
OBJDUMP=$(COMPILER_DIR)/llvm-objdump
PROFILER=$(LOCAL_TOOL_DIR)/misc/profile.py
SIMULATOR=$(BINDIR)/simulator
VERILATOR=$(BINDIR)/verilator_model
MKBMP=$(BINDIR)/mkbmp
CFLAGS=-g -Wall -W -O3 -fno-rtti -std=c++11 -I../libc -I../librender
BASE_ADDRESS=0

SRCS=main.cpp

OBJS := $(SRCS:%.cpp=$(WORKDIR)/%.o) $(WORKDIR)/start.o 
DEPS := $(SRCS:%.cpp=$(WORKDIR)/%.d)

$(WORKDIR)/program.hex: $(WORKDIR)/program.elf
	$(ELF2HEX) -b $(BASE_ADDRESS) -o $@ $<
	
$(WORKDIR)/program.elf: $(DEPS) $(OBJS) 
	$(LD) -Ttext=$(BASE_ADDRESS) -o $@ $(OBJS) ../libc/libc.a ../librender/librender.a
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

# Run in instruction set simulator
run: $(WORKDIR)/program.hex
	$(SIMULATOR) -d $(WORKDIR)/fb.bin,200000,12C000 $(WORKDIR)/program.hex
	$(MKBMP) $(WORKDIR)/fb.bin fb.bmp 640 480

# Run in verilator
verirun: $(WORKDIR)/program.hex
	$(VERILATOR) +memdumpfile=$(WORKDIR)/fb.bin +memdumpbase=200000 +memdumplen=12C000 +bin=$(WORKDIR)/program.hex
	$(MKBMP) $(WORKDIR)/fb.bin fb.bmp 640 480

# Profile code under verilator
profile: $(WORKDIR)/program.hex
	$(OBJDUMP) -t $(WORKDIR)/program.elf > $(WORKDIR)/syms.txt
	$(VERILATOR) +bin=$(WORKDIR)/program.hex +profile=$(WORKDIR)/profile.txt
	$(PROFILER) $(WORKDIR)/syms.txt $(WORKDIR)/profile.txt | c++filt -n

-include $(DEPS)

