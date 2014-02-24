# 
# Copyright 2011-2012 Jeff Bush
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

OBJDIR=OBJECTS
CFLAGS=-Wall -W -g -O3

SRCS=debugger.c main.c core.c cosimulation.c
LIBS=-lm -lreadline

OBJS := $(SRCS:%.c=$(OBJDIR)/%.o)
DEPS := $(SRCS:%.c=$(OBJDIR)/%.d)

ifeq ($(shell uname -s), Darwin)
	OBJS += cocoa.o
	LIBS += -framework Cocoa
	CFLAGS += -DENABLE_COCOA=1
endif

simulator: $(OBJS)
	gcc -g -o $@ $(OBJS) $(LIBS)

-include $(DEPS)

$(OBJDIR)/%.o : %.c
	mkdir -p $(dir $@)
	gcc $(CFLAGS) -o $@ -c $<
	gcc $(CFLAGS) -o $(OBJDIR)/$*.d -MM $<

clean:
	rm -rf $(OBJDIR)
	rm -rf simulator

