# 
# Copyright 2011-2015 Jeff Bush
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 



FB_WIDTH=640
FB_HEIGHT=480
MEMORY_SIZE=4000000

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
CFLAGS=-g -Wall -W -O3 -fno-rtti -std=c++11 -I$(TOPDIR)/software/libs/libc/include -I$(TOPDIR)/software/libs/librender -I$(TOPDIR)/software/libs/libos -DFB_WIDTH=$(FB_WIDTH) -DFB_HEIGHT=$(FB_HEIGHT)
BASE_ADDRESS=0
LIBS=$(TOPDIR)/software/libs/librender/librender.a $(TOPDIR)/software/libs/libc/libc.a $(TOPDIR)/software/libs/libos/libos.a

SRCS=main.cpp PakFile.cpp MeshBuilder.cpp Render.cpp

OBJS := $(SRCS:%.cpp=$(WORKDIR)/%.o)
DEPS := $(SRCS:%.cpp=$(WORKDIR)/%.d)

all: $(WORKDIR)/program.hex

$(WORKDIR)/program.hex: $(WORKDIR)/program.elf
	$(ELF2HEX) -b $(BASE_ADDRESS) -o $@ $<
	
$(WORKDIR)/program.elf: $(DEPS) $(OBJS) 
	$(LD) -Ttext=$(BASE_ADDRESS) -o $@ $(TOPDIR)/software/libs/libc/crt0.o $(OBJS) $(LIBS)

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
run: $(WORKDIR)/program.hex fsimage.bin
	rm -f $(WORKDIR)/output.bin output.png
	$(EMULATOR) -c 0x$(MEMORY_SIZE) -f $(FB_WIDTH)x$(FB_HEIGHT) -b fsimage.bin $(WORKDIR)/program.hex

# Run in emulator under debugger
debug: $(WORKDIR)/program.hex fsimage.bin
	$(EMULATOR) -m gdb -c 0x$(MEMORY_SIZE) -f $(FB_WIDTH)x$(FB_HEIGHT) -b fsimage.bin $(WORKDIR)/program.hex &
	$(COMPILER_DIR)/lldb --arch nyuzi $(WORKDIR)/program.elf -o "gdb-remote 8000" 

fpgarun: $(WORKDIR)/program.hex fsimage.bin
	../../../bin/serial_boot $(SERIAL_PORT) $(WORKDIR)/program.hex fsimage.bin

verirun: $(WORKDIR)/program.hex fsimage.bin
	@rm -f $(WORKDIR)/output.bin output.png
	$(VERILATOR) +memdumpfile=$(WORKDIR)/output.bin +memdumpbase=0x200000 +memdumplen=0x12C000 +bin=$(WORKDIR)/program.hex +block=fsimage.bin
	@convert -depth 8 -size 640x480 rgba:$(WORKDIR)/output.bin output.png

fsimage.bin: pak0.pak
	../../../bin/mkfs $@ pak0.pak
	
pak0.pak:
	@echo "Need to provide pak0.pak. See README"
	exit 1

FORCE:

-include $(DEPS)

