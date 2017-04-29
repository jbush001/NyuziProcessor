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

include $(TOPDIR)/build/tool.mk

TARGET=$(BINDIR)/emulator
CFLAGS+=$(shell sdl2-config --cflags)
#CFLAGS+=-DDUMP_INSTRUCTION_STATS

SRCS=main.c \
	processor.c \
	cosimulation.c \
	remote-gdb.c \
	device.c \
	fbwindow.c \
	sdmmc.c \
	util.c

LIBS=-lm $(shell sdl2-config --libs)

OBJS := $(SRCS_TO_OBJS)
DEPS := $(SRCS_TO_DEPS)

all: $(OBJDIR) $(BINDIR) $(TARGET)

$(TARGET): $(OBJS) $(DEPS)
	echo $(OBJS)
	$(CC) -g -o $@ $(OBJS) $(LIBS)

clean:
	rm -rf $(OBJ_DIR)
	rm -f $(TARGET)

$(BINDIR):
	mkdir -p $(BINDIR)

-include $(DEPS)
