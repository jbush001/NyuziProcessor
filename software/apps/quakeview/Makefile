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

TOPDIR=../../../

include $(TOPDIR)/build/target.mk

FB_WIDTH=640
FB_HEIGHT=480
MEMORY_SIZE=4000000

CFLAGS=-g -Wall -W -O3 -fno-rtti -std=c++11 -I$(TOPDIR)/software/libs/libc/include -I$(TOPDIR)/software/libs/librender -I$(TOPDIR)/software/libs/libos -DFB_WIDTH=$(FB_WIDTH) -DFB_HEIGHT=$(FB_HEIGHT)
BASE_ADDRESS=0
LIBS=$(TOPDIR)/software/libs/librender/librender.a $(TOPDIR)/software/libs/libc/libc.a $(TOPDIR)/software/libs/libos/libos.a

SRCS=main.cpp PakFile.cpp MeshBuilder.cpp Render.cpp

OBJS := $(SRCS_TO_OBJS)
DEPS := $(SRCS:%.cpp=$(OBJ_DIR)/%.d)

all: $(OBJ_DIR)/program.hex

$(OBJ_DIR)/program.hex: $(OBJ_DIR)/program.elf
	$(ELF2HEX) -b $(BASE_ADDRESS) -o $@ $<
	
$(OBJ_DIR)/program.elf: $(DEPS) $(OBJS) 
	$(LD) -Ttext=$(BASE_ADDRESS) -o $@ $(TOPDIR)/software/libs/libc/crt0.o $(OBJS) $(LIBS)

program.lst: $(OBJ_DIR)/program.elf FORCE
	$(OBJDUMP) --disassemble WORK/program.elf > program.lst 2> /dev/null	# Make disassembly file

clean:
	rm -rf $(OBJ_DIR)

# Run in emulator
run: $(OBJ_DIR)/program.hex fsimage.bin
	rm -f $(OBJ_DIR)/output.bin output.png
	$(EMULATOR) -c 0x$(MEMORY_SIZE) -f $(FB_WIDTH)x$(FB_HEIGHT) -b fsimage.bin $(OBJ_DIR)/program.hex

# Run in emulator under debugger
debug: $(OBJ_DIR)/program.hex fsimage.bin
	$(EMULATOR) -m gdb -c 0x$(MEMORY_SIZE) -f $(FB_WIDTH)x$(FB_HEIGHT) -b fsimage.bin $(OBJ_DIR)/program.hex &
	$(COMPILER_DIR)/lldb --arch nyuzi $(OBJ_DIR)/program.elf -o "gdb-remote 8000" 

fpgarun: $(OBJ_DIR)/program.hex fsimage.bin
	../../../bin/serial_boot $(SERIAL_PORT) $(OBJ_DIR)/program.hex fsimage.bin

verirun: $(OBJ_DIR)/program.hex fsimage.bin
	@rm -f $(OBJ_DIR)/output.bin output.png
	$(VERILATOR) +memdumpfile=$(OBJ_DIR)/output.bin +memdumpbase=0x200000 +memdumplen=0x12C000 +bin=$(OBJ_DIR)/program.hex +block=fsimage.bin
	@convert -depth 8 -size 640x480 rgba:$(OBJ_DIR)/output.bin output.png

fsimage.bin: pak0.pak
	../../../bin/mkfs $@ pak0.pak
	
pak0.pak:
	@echo "Need to provide pak0.pak. See README"
	exit 1

FORCE:

-include $(DEPS)

