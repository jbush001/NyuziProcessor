# 
# Copyright 2011-2015 Pipat Methavanitpong
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

TOOLDIR=/usr/local/llvm-nyuzi/bin
CC=$(TOOLDIR)/clang
ELF2HEX=$(TOOLDIR)/elf2hex
CFLAGS=-O3 -I../../../software/libs/libc/include

uart.hex: uart.c 
	$(CC) $(CFLAGS) uart.c -o uart.elf ../../../software/libs/libc/crt0.o ../../../software/libs/libc/libc.a ../../../software/libs/libos/libos.a
	$(ELF2HEX) -o uart.hex uart.elf

test: uart.hex
	../../../bin/verilator_model +bin=uart.hex

clean: FORCE
	rm -f uart.elf uart.hex

FORCE:

