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

CFLAGS=-O3  # Override default CFLAGS, since this builds standalone
BASE_ADDRESS=0xfffee000

SRCS=boot.c start.s

OBJS=$(SRCS_TO_OBJS)
DEPS=$(SRCS_TO_DEPS)

boot.hex: $(OBJS) $(DEPS)
	$(LD) -o $(OBJ_DIR)/boot.elf --image-base=$(BASE_ADDRESS) $(OBJS) $(TOPDIR)/software/libs/compiler-rt/compiler-rt.a
	$(ELF2HEX) -b $(BASE_ADDRESS) -o boot.hex $(OBJ_DIR)/boot.elf

clean:
	rm -rf obj boot.hex

-include $(DEPS)

