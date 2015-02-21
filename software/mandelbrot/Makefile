# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 

TOOLDIR=/usr/local/llvm-nyuzi/bin
CC=$(TOOLDIR)/clang
ELF2HEX=$(TOOLDIR)/elf2hex
CFLAGS=-O3 -I../libc/include

mandelbrot.hex: mandelbrot.c 
	$(CC) $(CFLAGS) mandelbrot.c ../libc/crt0.o ../libc/libc.a -o mandelbrot.elf
	$(ELF2HEX) -o mandelbrot.hex mandelbrot.elf

run: mandelbrot.hex
	../../bin/emulator -f 640x480 mandelbrot.hex

clean: FORCE
	rm -f mandelbrot.elf mandelbrot.hex

FORCE:

