#!/bin/sh
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

run:
	$(AS) -o blinky.elf blinky.S
	$(ELF2HEX) -o blinky.hex blinky.elf
	$(SERIAL_BOOT) $(SERIAL_PORT) blinky.hex

clean: 
	rm -f blinky.elf blinky.hex