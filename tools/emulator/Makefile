# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 

BINDIR=../../bin
TARGET=$(BINDIR)/emulator
OBJDIR=OBJECTS
CFLAGS = -Wall -W -Wno-unused-result -Wno-unused-parameter -Wno-strict-aliasing -O3 $(shell sdl2-config --cflags)

#CFLAGS += -DLOG_INSTRUCTIONS=1

SRCS=main.c \
	core.c \
	cosimulation.c \
	remote-gdb.c \
	device.c \
	stats.c \
	util.c \
	fbwindow.c

LIBS=-lm $(shell sdl2-config --libs)

OBJS := $(SRCS:%.c=$(OBJDIR)/%.o)
DEPS := $(SRCS:%.c=$(OBJDIR)/%.d)

all: $(OBJDIR) $(BINDIR) $(TARGET)

$(TARGET): $(OBJS)
	gcc -g -o $@ $(OBJS) $(LIBS)

-include $(DEPS)

$(OBJDIR)/%.o : %.c
	gcc $(CFLAGS) -o $@ -c $<
	gcc $(CFLAGS) -o $(OBJDIR)/$*.d -MM $<

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(BINDIR):
	mkdir -p $(BINDIR)

clean:
	rm -rf $(OBJDIR)
	rm -f $(TARGET)

