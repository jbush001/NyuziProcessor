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

WORKDIR=WORK
COMPILER_DIR=/usr/local/llvm-nyuzi/bin
CC=$(COMPILER_DIR)/clang
AR=$(COMPILER_DIR)/llvm-ar

CFLAGS=-g -Wall -W -O3 -fno-rtti -std=c++11 -I../libc/include -I../libos/

SRCS=Texture.cpp \
	Surface.cpp \
	VertexShader.cpp \
	LinearInterpolator.cpp \
	ParameterInterpolator.cpp \
	Rasterizer.cpp \
	RenderContext.cpp \
	line.cpp \
	ShaderFiller.cpp \
	clear.s

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
