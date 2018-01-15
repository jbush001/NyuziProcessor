#
# Copyright (C) 2011-2014 Jeff Bush
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

# This file is included in the sub makefiles

TOPDIR=../../../

COMPILER_DIR=/usr/local/llvm-nyuzi/bin
BINDIR=$(TOPDIR)/bin
BUILDDIR=$(TOPDIR)/build
OBJ_DIR=obj

CC=$(COMPILER_DIR)/clang
CXX=$(COMPILER_DIR)/clang++
LD=$(COMPILER_DIR)/ld.lld
AR=$(COMPILER_DIR)/llvm-ar
AS=$(COMPILER_DIR)/clang
OBJDUMP=$(COMPILER_DIR)/llvm-objdump
ELF2HEX=$(COMPILER_DIR)/elf2hex
LLDB=$(COMPILER_DIR)/lldb
EMULATOR=$(BINDIR)/nyuzi_emulator
VERILATOR=$(BINDIR)/nyuzi_vsim
VCSRUN=$(BUILDDIR)/vcsrun.pl
SERIAL_BOOT=$(BINDIR)/serial_boot
MKFS=$(BINDIR)/mkfs

CFLAGS=-O3 -I$(TOPDIR)/software/libs/libc/include -I$(TOPDIR)/software/libs/libos -Wall -W
LDFLAGS=-L$(TOPDIR)/software/libs/libc/ -L$(TOPDIR)/software/libs/libos/bare-metal -L$(TOPDIR)/software/libs/librender $(TOPDIR)/software/libs/compiler-rt/libcompiler-rt.a

define SRCS_TO_OBJS
	$(addprefix $(OBJ_DIR)/, $(addsuffix .o, $(foreach file, $(SRCS), $(basename $(notdir $(file))))))
endef

define SRCS_TO_DEPS
	$(addprefix $(OBJ_DIR)/, $(addsuffix .d, $(foreach file, $(filter-out %.s, $(SRCS)), $(basename $(notdir $(file))))))
endef

$(OBJ_DIR)/%.o: %.cpp
	@echo "Compiling $<"
	@$(CXX) $(CFLAGS) -o $@ -c $<

$(OBJ_DIR)/%.o: %.c
	@echo "Compiling $<"
	@$(CC) $(CFLAGS) -o $@ -c $<

$(OBJ_DIR)/%.o: %.s
	@echo "Assembling $<"
	@$(AS) -o $@ -c $<

$(OBJ_DIR)/%.o: %.S
	@echo "Assembling $<"
	@$(AS) -o $@ -c $<

$(OBJ_DIR)/%.d: %.cpp
	@echo "Building dependencies for $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -o $(OBJ_DIR)/$*.d -M -MT $(OBJ_DIR)/$(notdir $(basename $<)).o $<

$(OBJ_DIR)/%.d: %.c
	@echo "Building dependencies for $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -o $(OBJ_DIR)/$*.d -M -MT $(OBJ_DIR)/$(notdir $(basename $<)).o $<

$(OBJ_DIR)/%.d: %.S
	@echo "Building dependencies for $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -o $(OBJ_DIR)/$*.d -M -MT $(OBJ_DIR)/$(notdir $(basename $<)).o $<

CFLAGS+=-g -Wall -W -fno-rtti -std=c++11 -ffast-math -I$(TOPDIR)/software/libs/librender
LIBS=-lrender -lc -los-bare

OBJS := $(SRCS_TO_OBJS)
DEPS := $(SRCS_TO_DEPS)

$(OBJ_DIR)/program.hex: $(OBJ_DIR)/program.elf
	$(ELF2HEX) -o $@ $<

$(OBJ_DIR)/program.elf: $(DEPS) $(OBJS)
	$(LD) -o $@ $(OBJS) $(LIBS) $(LDFLAGS)

program.lst: $(OBJ_DIR)/program.elf
	$(OBJDUMP) --disassemble $(OBJ_DIR)/program.elf > program.lst 2> /dev/null	# Make disassembly file

clean:
	rm -rf $(OBJ_DIR)

# Run in emulator. Dump rendered framebuffer to a file 'output.png'.
run: $(OBJ_DIR)/program.hex
	@rm -f $(OBJ_DIR)/output.bin output.png
	$(EMULATOR) -a -d $(OBJ_DIR)/output.bin,0x200000,0x12C000 $(OBJ_DIR)/program.hex
	@convert -depth 8 -size 640x480 rgba:$(OBJ_DIR)/output.bin output.png

# Run in verilator. Dump rendered framebuffer to a file 'output.png'.
verirun: $(OBJ_DIR)/program.hex
	@rm -f $(OBJ_DIR)/output.bin output.png
	$(VERILATOR) +memdumpfile=$(OBJ_DIR)/output.bin +memdumpbase=200000 +memdumplen=12C000 +bin=$(OBJ_DIR)/program.hex
	@convert -depth 8 -size 640x480 rgba:$(OBJ_DIR)/output.bin output.png

# Test (emulator only). Run program and compare checksum of framebuffer to
# value in Makefile. If they do not match, return an error.
test: $(OBJ_DIR)/program.hex
	@rm -f $(OBJ_DIR)/output.bin output.png
	$(EMULATOR) -a -d $(OBJ_DIR)/output.bin,0x200000,0x12C000 $(OBJ_DIR)/program.hex
	@shasum $(OBJ_DIR)/output.bin | awk '{if ($$1!=$(IMAGE_CHECKSUM)) {print "FAIL: bad checksum, expected " $(IMAGE_CHECKSUM) " got " $$1; exit 1}}'
	@echo "PASS"

# Compile and send to FPGA board over serial port.
fpgarun: $(OBJ_DIR)/program.hex
	$(SERIAL_BOOT) $(SERIAL_PORT) $(OBJ_DIR)/program.hex

# Run in emulator under debugger
debug: $(OBJ_DIR)/program.hex
	$(EMULATOR) -m gdb $(OBJ_DIR)/program.hex &
	$(COMPILER_DIR)/lldb --arch nyuzi $(OBJ_DIR)/program.elf -o "gdb-remote 8000"

# Generate a profile
profile: $(OBJ_DIR)/program.hex FORCE
	$(VERILATOR) +bin=$(OBJ_DIR)/program.hex +profile=prof.txt
	$(OBJDUMP) -t $(OBJ_DIR)//program.elf > $(OBJ_DIR)/syms.txt
	python $(TOPDIR)/tools/misc/profile.py $(OBJ_DIR)/syms.txt prof.txt

FORCE:

-include $(DEPS)

