#
# Copyright 2011-2017 Jeff Bush
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

LIBS=-lc
SRCS=hello_world.c
CFLAGS+=-Werror
HEX_FILE=$(OBJ_DIR)/hello_world.hex

OBJS := $(SRCS_TO_OBJS)
DEPS := $(SRCS_TO_DEPS)

$(HEX_FILE): $(CRT0_BARE) $(OBJS)
	$(LD) -o $(OBJ_DIR)/hello_world.elf $(LDFLAGS) $(CRT0_BARE) $(OBJS) $(LIBS) -los-bare $(LDFLAGS)
	$(ELF2HEX) -o $(HEX_FILE) $(OBJ_DIR)/hello_world.elf

run: $(HEX_FILE)
	$(EMULATOR) $(HEX_FILE)

verirun: $(HEX_FILE)
	$(VERILATOR) +bin=$(HEX_FILE)

vcsrun: $(HEX_FILE)
	$(VCSRUN) +bin=$(HEX_FILE)

clean:
	rm -rf $(OBJ_DIR)

-include $(DEPS)

