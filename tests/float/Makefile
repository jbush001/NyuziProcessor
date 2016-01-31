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

TEST_FILES = f32_add.test    \
	f32_le.test    \
	f32_lt.test     \
	f32_mul.test    \
	f32_sub.test    \
	f32_to_i32.test \
	i32_to_f32.test

LIBS=-lc -los

SRCS=test_float.c

OBJS := $(TOPDIR)/software/libs/libc/crt0.o $(SRCS_TO_OBJS)
DEPS := $(SRCS_TO_DEPS)

$(OBJ_DIR)/test_float.hex: $(OBJS) $(DEPS)
	$(LD) $(OBJS) -o $(OBJ_DIR)/test_float.elf $(LIBS) $(LDFLAGS)
	$(ELF2HEX) -o $@ $(OBJ_DIR)/test_float.elf

fsimage.bin:
	$(MKFS) $@ $(TEST_FILES)

test: $(OBJ_DIR)/test_float.hex fsimage.bin
	$(EMULATOR) -b fsimage.bin $(OBJ_DIR)/test_float.hex

vtest: $(OBJ_DIR)/test_float.hex fsimage.bin
	$(VERILATOR) +block=fsimage.bin +bin=$(OBJ_DIR)/test_float.hex

clean: FORCE
	rm -f $(OBJ_DIR)/*

FORCE:

-include $(DEPS)
