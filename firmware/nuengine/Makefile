# 
# Copyright 2011-2012 Jeff Bush
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

WORKDIR=WORK
LOCAL_TOOL_DIR=../../tools
COMPILER_DIR=/usr/local/llvm-vectorproc/bin
CC=$(COMPILER_DIR)/clang
AS=$(COMPILER_DIR)/llvm-mc
LD=$(COMPILER_DIR)/lld
ISS=$(LOCAL_TOOL_DIR)/simulator/iss
MKBMP=$(LOCAL_TOOL_DIR)/mkbmp/mkbmp
CFLAGS=-Wall -W -integrated-as -target vectorproc -O3
ASFLAGS=-filetype=obj -triple vectorproc-elf
LDFLAGS=-flavor gnu -target vectorproc  -static

SRCS=main.cpp \
	Rasterizer.cpp \
	ParameterInterpolator.cpp \
	PixelShader.cpp \
	LinearInterpolator.cpp \
	utils.cpp

OBJS := $(SRCS:%.cpp=$(WORKDIR)/%.o) $(WORKDIR)/start.o
DEPS := $(SRCS:%.cpp=$(WORKDIR)/%.d)

$(WORKDIR)/program.hex: $(WORKDIR)/program.elf
	$(LOCAL_TOOL_DIR)/flatten_elf/flatten_elf $@ $<
	
$(WORKDIR)/program.elf: $(DEPS) $(OBJS) 
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

$(WORKDIR)/%.o : %.cpp 
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -o $@ -c $<
	
$(WORKDIR)/%.o : %.s
	@echo "Assembling $<..."
	$(AS) $(ASFLAGS) -o $@ $<

$(WORKDIR)/%.d: %.cpp
	@echo "Building dependencies for $<..."
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $(WORKDIR)/$*.d -MM $<

clean:
	rm -rf $(WORKDIR)

run: $(WORKDIR)/program.hex
	$(ISS) -d $(WORKDIR)/fb.bin,100000,12C000 $(WORKDIR)/program.hex
	$(MKBMP) $(WORKDIR)/fb.bin fb.bmp 640 480 

-include $(DEPS)

