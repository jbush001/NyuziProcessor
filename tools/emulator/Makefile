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

BINDIR=../../bin
TARGET=$(BINDIR)/emulator
OBJDIR=OBJECTS

ifneq (,$(findstring clang, $(shell $(CC) --version)))
	# -Weverything is only supported on clang
	WARNINGS =-Weverything -Wno-padded -Wno-float-equal -Wno-covered-switch-default -Wno-switch-enum -Wno-bad-function-cast -Wno-documentation -Wno-documentation-unknown-command
else
	WARNINGS=-Wall -W 
endif

CFLAGS=-O3 $(WARNINGS) $(shell sdl2-config --cflags)

#CFLAGS += -DLOG_INSTRUCTIONS

SRCS=main.c \
	core.c \
	cosimulation.c \
	remote-gdb.c \
	device.c \
	stats.c \
	util.c \
	fbwindow.c \
	sdmmc.c

LIBS=-lm $(shell sdl2-config --libs)

OBJS := $(SRCS:%.c=$(OBJDIR)/%.o)
DEPS := $(SRCS:%.c=$(OBJDIR)/%.o.d)

all: $(OBJDIR) $(BINDIR) $(TARGET)

$(TARGET): $(OBJS)
	gcc -g -o $@ $(OBJS) $(LIBS)

$(OBJDIR)/%.o: %.c
	$(CC) -o $@ $(CFLAGS) -c $< -MMD -MF $@.d

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(BINDIR):
	mkdir -p $(BINDIR)

clean:
	rm -rf $(OBJDIR)
	rm -f $(TARGET)

-include $(DEPS)
