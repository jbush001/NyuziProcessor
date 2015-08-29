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

TOPDIR=../../..

include $(TOPDIR)/build/target.mk

CFLAGS=-O3 -I../../../software/libs/libc/include -I../../../software/libs/libos

ps2.hex: ps2.c 
	$(CC) $(CFLAGS) ps2.c -o ps2.elf ../../../software/libs/libc/crt0.o ../../../software/libs/libc/libc.a ../../../software/libs/libos/libos.a
	$(ELF2HEX) -o ps2.hex ps2.elf

test: ps2.hex
	../../../bin/verilator_model +bin=ps2.hex

clean: FORCE
	rm -f ps2.elf ps2.hex

FORCE:

