#
# Copyright 2015 Jeff Bush
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

#
# This is included by makefiles that compile programs that run on the Nyuzi
# architecture, either in the emulator, FPGA, or Verilog simulation.
#

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
EMULATOR=$(BINDIR)/emulator
VERILATOR=$(BINDIR)/verilator_model
VCSRUN=$(BUILDDIR)/vcsrun.pl
SERIAL_BOOT=$(BINDIR)/serial_boot
MKFS=$(BINDIR)/mkfs
CRT0_BARE=$(TOPDIR)/software/libs/libos/crt0-bare.o
CRT0_KERN=$(TOPDIR)/software/libs/libos/crt0-kern.o

CFLAGS=-O3 -I$(TOPDIR)/software/libs/libc/include -I$(TOPDIR)/software/libs/libos -Wall -W
LDFLAGS=-L$(TOPDIR)/software/libs/libc/ -L$(TOPDIR)/software/libs/libos -L$(TOPDIR)/software/libs/librender $(TOPDIR)/software/libs/compiler-rt/compiler-rt.a

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

