#
# Copyright 2016 Jeff Bush
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

TOPDIR=../../..

include $(TOPDIR)/build/target.mk

LIBS=-lc
SRCS=memtest.c

OBJS=$(SRCS_TO_OBJS)
DEPS=$(SRCS_TO_DEPS)

memtest.elf: $(OBJS)
	$(LD) -o memtest.elf --image-base=0x1000 $(LDFLAGS) $(CRT0_KERN) $(OBJS) -los-kern $(LIBS) -los-kern $(LDFLAGS)

clean:
	rm -f memtest.elf

-include $(DEPS)
