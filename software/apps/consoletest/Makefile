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

LIBS=-lc -lconsole
SRCS=consoletest.cpp
CFLAGS+=-I$(TOPDIR)/software/libs/libconsole -Werror
LDFLAGS+=-L$(TOPDIR)/software/libs/libconsole
HEX_FILE=$(OBJ_DIR)/consoletest.hex

OBJS := $(SRCS_TO_OBJS)
DEPS := $(SRCS_TO_DEPS)

$(HEX_FILE): $(OBJS)
	$(LD) -o $(OBJ_DIR)/consoletest.elf $(LDFLAGS) $(CRT0_BARE) $(OBJS) $(LIBS) -los-bare $(LDFLAGS)
	$(ELF2HEX) -o $(HEX_FILE) $(OBJ_DIR)/consoletest.elf

run: $(HEX_FILE)
	$(EMULATOR) -f 640x480 $(HEX_FILE)

clean:
	rm -rf $(OBJ_DIR) fsimage.bin

-include $(DEPS)

