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

TOPDIR=../../../../

include $(TOPDIR)/build/target.mk

CFLAGS+=-I.. -Werror

SRCS=schedule.c \
	uart.c \
	sdmmc.c \
	fs.c \
	keyboard.c \
	misc.c \
	sbrk.c \
	vga.c \
	performance_counters.c \
	nyuzi.c

OBJS := $(SRCS_TO_OBJS)
DEPS := $(SRCS_TO_DEPS)

all: $(OBJ_DIR) ../libos-bare.a ../crt0-bare.o

../libos-bare.a: $(DEPS) $(OBJS)
	$(AR) r $@ $(OBJS)

../crt0-bare.o: crt0.s
	$(CC) -o $@ -c $<

clean:
	rm -rf $(OBJ_DIR)
	rm -f libos.a

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

-include $(DEPS)

