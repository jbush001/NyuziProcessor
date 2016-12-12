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

MODEL_FILE=dabrovik_sponza/sponza.obj
FB_WIDTH=640
FB_HEIGHT=480
MEMORY_SIZE=8000000

CFLAGS+=-fno-rtti -ffast-math -std=c++11 -I$(TOPDIR)/software/libs/librender -DFB_WIDTH=$(FB_WIDTH) -DFB_HEIGHT=$(FB_HEIGHT)
LIBS=-lrender -lc -los-bare

SRCS=sceneview.cpp

OBJS := $(CRT0_BARE) $(SRCS_TO_OBJS)
DEPS := $(SRCS_TO_DEPS)

all: $(OBJ_DIR)/program.hex fsimage.bin

$(OBJ_DIR)/program.hex: $(OBJ_DIR)/program.elf
	$(ELF2HEX) -o $@ $<

$(OBJ_DIR)/program.elf: $(DEPS) $(OBJS)
	$(LD) -o $@ $(OBJS) $(LIBS) $(LDFLAGS)

# Make disassembly file
program.lst: $(OBJ_DIR)/program.elf FORCE
	$(OBJDUMP) --disassemble $(OBJ_DIR)/program.elf > program.lst 2> /dev/null

clean:
	rm -rf $(OBJ_DIR)

# Run in emulator
run: $(OBJ_DIR)/program.hex fsimage.bin
	rm -f $(OBJ_DIR)/output.bin output.png
	$(EMULATOR) -t 4 -c 0x$(MEMORY_SIZE) -f $(FB_WIDTH)x$(FB_HEIGHT) -b fsimage.bin $(OBJ_DIR)/program.hex

# Run in emulator under debugger
debug: $(OBJ_DIR)/program.hex fsimage.bin
	$(EMULATOR) -m gdb -c 0x$(MEMORY_SIZE) -f $(FB_WIDTH)x$(FB_HEIGHT) -b fsimage.bin $(OBJ_DIR)/program.hex &
	$(LLDB) --arch nyuzi $(OBJ_DIR)/program.elf -o "gdb-remote 8000"

verirun: $(OBJ_DIR)/program.hex
	@rm -f $(OBJ_DIR)/output.bin output.png
	$(VERILATOR) +memdumpfile=$(OBJ_DIR)/output.bin +memdumpbase=200000 +memdumplen=12C000 +bin=$(OBJ_DIR)/program.hex +block=fsimage.bin
	@convert -depth 8 -size 640x480 rgba:$(OBJ_DIR)/output.bin output.png

fpgarun: $(OBJ_DIR)/program.hex
	$(SERIAL_BOOT) $(SERIAL_PORT) $(OBJ_DIR)/program.hex fsimage.bin

fsimage.bin:
	./make_resource_file.py $(MODEL_FILE)
	$(MKFS) $@ resource.bin

FORCE:

-include $(DEPS)

