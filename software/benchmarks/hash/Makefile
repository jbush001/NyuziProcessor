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

TOPDIR=../../../

include $(TOPDIR)/build/target.mk

LIBS=-lc -los-bare
CFLAGS+=-Werror

SRCS=hash.cpp

OBJS=$(CRT0_BARE) $(SRCS_TO_OBJS)
DEPS=$(SRCS_TO_DEPS)

$(OBJ_DIR)/hash.hex: $(OBJS)
	$(LD) -o $(OBJ_DIR)/hash.elf $(LDFLAGS) $(OBJS) $(LIBS) $(LDFLAGS)
	$(ELF2HEX) -o $(OBJ_DIR)/hash.hex $(OBJ_DIR)/hash.elf

run: $(OBJ_DIR)/hash.hex
	$(EMULATOR) $(OBJ_DIR)/hash.hex

verirun: $(OBJ_DIR)/hash.hex
	$(VERILATOR) +bin=$(OBJ_DIR)/hash.hex

clean:
	rm -rf $(OBJ_DIR)

-include $(DEPS)

