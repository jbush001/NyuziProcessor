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
	stdlib.c \
	ashldi3.s \
	lshrdi3.s \
	qsort.c \
	builtins.c \
	setjmp.s \
	memcpy.s

OBJS := $(addprefix $(WORKDIR),$(notdir $(patsubst %.c,%.o,$(filter %.c,$(SRCS))))) \
	$(addprefix $(WORKDIR),$(notdir $(patsubst %.s,%.o,$(filter %.s,$(SRCS))))) \
	$(addprefix $(WORKDIR),$(notdir $(patsubst %.cpp,%.o,$(filter %.cpp,$(SRCS)))))

all: $(WORKDIR) libc.a crt0.o

libc.a: $(OBJS) 
	$(AR) r $@ $(OBJS)

crt0.o: src/crt0.s
	$(CC) -o $@ -c $<

clean:
	rm -rf $(WORKDIR)
	rm -f libc.a
	rm -f crt0.o

$(WORKDIR)%.o: src/%.c
	$(CC) $(CFLAGS) -o $@ -c $<

$(WORKDIR)%.o: src/%.cpp
	$(CC) $(CFLAGS) -o $@ -c $<

$(WORKDIR)%.o: src/%.s
	$(CC) $(CFLAGS) -o $@ -c $<

$(WORKDIR):
	mkdir -p $(WORKDIR)
