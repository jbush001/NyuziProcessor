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

CFLAGS=-O3 -Werror # Override default CFLAGS, since this builds standalone

SRCS=start.s boot.c

OBJS=$(SRCS_TO_OBJS)
DEPS=$(SRCS_TO_DEPS)

boot.bin: $(OBJS)
	$(LD) -o $(OBJ_DIR)/boot.bin --script boot.ld --oformat binary $(OBJS) $(TOPDIR)/software/libs/compiler-rt/compiler-rt.a
	$(TOPDIR)/tools/misc/bin2hex.py $(OBJ_DIR)/boot.bin > boot.hex

clean:
	rm -rf obj boot.hex

-include $(DEPS)

