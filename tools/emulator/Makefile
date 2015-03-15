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
CFLAGS = -Wall -W -Wno-unused-result -Wno-unused-parameter -O3 $(shell sdl2-config --cflags)

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

