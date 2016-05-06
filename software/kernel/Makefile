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

TOPDIR=../../

include $(TOPDIR)/build/target.mk

CFLAGS=-O3 # Override default CFLAGS
BASE_ADDRESS=0xc0000000

SRCS=vm.c \
	main.c \
	start.S \
	libc.c \
	uart.c \
	trap_entry.S \
	trap.c

OBJS=$(SRCS_TO_OBJS)
DEPS=$(SRCS_TO_DEPS)

kernel.hex: kernel.elf
	$(ELF2HEX) -b $(BASE_ADDRESS) -o kernel.hex $(OBJ_DIR)/kernel.elf

kernel.elf: $(OBJS) $(DEPS)
	$(LD) -o $(OBJ_DIR)/kernel.elf -Ttext=$(BASE_ADDRESS) $(OBJS) $(TOPDIR)/software/libs/compiler-rt/compiler-rt.a
	$(OBJDUMP) --disassemble $(OBJ_DIR)/kernel.elf > kernel.lst

run: kernel.hex
	$(EMULATOR) kernel.hex

verirun: kernel.hex
	$(VERILATOR) +bin=kernel.hex

clean:
	rm -rf obj $(OBJ_DIR)/kernel.elf

-include $(DEPS)
