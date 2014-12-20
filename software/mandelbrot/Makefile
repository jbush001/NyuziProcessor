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


TOOLDIR=/usr/local/llvm-nyuzi/bin
CC=$(TOOLDIR)/clang
ELF2HEX=$(TOOLDIR)/elf2hex
CFLAGS=-O3 -I../libc/include

mandelbrot.hex: mandelbrot.c start.s
	$(CC) $(CFLAGS) mandelbrot.c start.s ../libc/libc.a -o mandelbrot.elf
	$(ELF2HEX) -o mandelbrot.hex mandelbrot.elf

run: mandelbrot.hex
	../../bin/emulator -f 640x480 mandelbrot.hex

clean: FORCE
	rm -f mandelbrot.elf mandelbrot.hex

FORCE:

