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

CFLAGS+=-g -Werror

SRCS=ashldi3.s \
	divsi3.c \
	divdi3.c \
	lshrdi3.s \
	modsi3.c \
	moddi3.c \
	udivsi3.s \
	udivdi3.c \
	umodsi3.c \
	umoddi3.c \
	floatundisf.c

OBJS := $(SRCS_TO_OBJS)
DEPS := $(SRCS_TO_DEPS)

all: $(OBJ_DIR) compiler-rt.a

compiler-rt.a: $(DEPS) $(OBJS)
	$(AR) r $@ $(OBJS)

clean:
	rm -rf $(OBJ_DIR)
	rm -f compiler-rt.a

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

-include $(DEPS)

