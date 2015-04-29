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

COMPILER_DIR=/usr/local/llvm-nyuzi/bin
CC=$(COMPILER_DIR)/clang
LD=$(COMPILER_DIR)/ld.mcld
ELF2HEX=$(COMPILER_DIR)/elf2hex
CFLAGS=-O3
BASE_ADDRESS=0xfffee000

boot.hex: boot.c start.s
	$(CC) $(CFLAGS) -c start.s 
	$(CC) $(CFLAGS) -c boot.c
	$(LD) -o boot.elf -Ttext=$(BASE_ADDRESS) start.o boot.o
	$(ELF2HEX) -b $(BASE_ADDRESS) -o boot.hex boot.elf

clean: FORCE
	rm -f boot.elf boot.hex start.o boot.o

FORCE:

