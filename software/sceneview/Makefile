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
OBJDUMP=$(COMPILER_DIR)/llvm-objdump
ELF2HEX=$(COMPILER_DIR)/elf2hex
PROFILER=$(LOCAL_TOOL_DIR)/misc/profile.py
EMULATOR=$(BINDIR)/emulator
VERILATOR=$(BINDIR)/verilator_model
CFLAGS=-g -Wall -W -O3 -fno-rtti -ffast-math -std=c++11 -I$(TOPDIR)/software/libc/include -I$(TOPDIR)/software/libos -I$(TOPDIR)/software/librender -I$(TOPDIR)/software/libos -DFB_WIDTH=$(FB_WIDTH) -DFB_HEIGHT=$(FB_HEIGHT)
BASE_ADDRESS=0
LIBS=$(TOPDIR)/software/librender/librender.a $(TOPDIR)/software/libc/libc.a $(TOPDIR)/software/libos/libos.a

SRCS=sceneview.cpp

OBJS := $(SRCS:%.cpp=$(WORKDIR)/%.o)
DEPS := $(SRCS:%.cpp=$(WORKDIR)/%.d)

all: $(WORKDIR)/program.hex resource.bin

$(WORKDIR)/program.hex: $(WORKDIR)/program.elf
	$(ELF2HEX) -b $(BASE_ADDRESS) -o $@ $<
	
$(WORKDIR)/program.elf: $(DEPS) $(OBJS) 
	$(LD) -Ttext=$(BASE_ADDRESS) -o $@ $(TOPDIR)/software/libc/crt0.o $(OBJS) $(LIBS)

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

