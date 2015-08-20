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

TOOLDIR=/usr/local/llvm-nyuzi/bin
CC=$(TOOLDIR)/clang
ELF2HEX=$(TOOLDIR)/elf2hex
CFLAGS=-O3 -I../../libs/libc/include -std=c++11

plasma.hex: plasma.cpp
	$(CC) $(CFLAGS) plasma.cpp ../../libs/libc/crt0.o ../../libs/libc/libc.a ../../libs/libos/libos.a -o plasma.elf
	$(ELF2HEX) -o plasma.hex plasma.elf

run: plasma.hex
	../../../bin/emulator -f 640x480 plasma.hex

fpgarun: plasma.hex
	../../../bin/serial_boot $(SERIAL_PORT) plasma.hex

clean: FORCE
	rm -f plasma.elf plasma.hex

FORCE:

