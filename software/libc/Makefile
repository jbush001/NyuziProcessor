# 
# Copyright (C) 2014 Jeff Bush
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

WORKDIR=WORK/
COMPILER_DIR=/usr/local/llvm-nyuzi/bin
CC=$(COMPILER_DIR)/clang
AR=$(COMPILER_DIR)/llvm-ar

CFLAGS=-g -Wall -W -O3 -Iinclude

SRCS=math.c \
	stdio.c \
	string.c \
	dlmalloc.c \
	sbrk.c \
	cxx_runtime.cpp \
	abort.c \
	ashldi3.s \
	lshrdi3.s \
	qsort.c \
	builtins.c \
	setjmp.s \
	memcpy.s

OBJS := $(addprefix $(WORKDIR),$(notdir $(patsubst %.c,%.o,$(filter %.c,$(SRCS))))) \
	$(addprefix $(WORKDIR),$(notdir $(patsubst %.s,%.o,$(filter %.s,$(SRCS))))) \
	$(addprefix $(WORKDIR),$(notdir $(patsubst %.cpp,%.o,$(filter %.cpp,$(SRCS)))))

all: $(WORKDIR) libc.a

libc.a: $(OBJS) 
	$(AR) r $@ $(OBJS)

clean:
	rm -rf $(WORKDIR)
	rm -f libc.a

$(WORKDIR)%.o: src/%.c
	$(CC) $(CFLAGS) -o $@ -c $<

$(WORKDIR)%.o: src/%.cpp
	$(CC) $(CFLAGS) -o $@ -c $<

$(WORKDIR)%.o: src/%.s
	$(CC) $(CFLAGS) -o $@ -c $<

$(WORKDIR):
	mkdir -p $(WORKDIR)
