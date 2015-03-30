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


WORKDIR=WORK
COMPILER_DIR=/usr/local/llvm-nyuzi/bin
CC=$(COMPILER_DIR)/clang
AR=$(COMPILER_DIR)/llvm-ar

CFLAGS=-g -Wall -W -O3 -fno-rtti -std=c++11 -ffast-math -I../libc/include -I../libos/

SRCS=Texture.cpp \
	Surface.cpp \
	VertexShader.cpp \
	Rasterizer.cpp \
	RenderContext.cpp \
	line.cpp \
	ShaderFiller.cpp

OBJS := $(SRCS:%.cpp=$(WORKDIR)/%.o) $(SRCS:%.s=$(WORKDIR)/%.o) 

all: $(WORKDIR) librender.a 

librender.a: $(OBJS) 
	$(AR) r $@ $(OBJS)

clean:
	rm -rf $(WORKDIR)
	rm -f librender.a

$(WORKDIR)/%.o : %.cpp
	$(CC) $(CFLAGS) -o $@ -c $<

$(WORKDIR)/%.o : %.s
	$(CC) -o $@ -c $<

$(WORKDIR):
	mkdir -p $(WORKDIR)
