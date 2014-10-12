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

JAVAC := $(shell which javac)

all:
	cd tools/simulator && make
	cd tools/mkbmp && make
	cd rtl/ && make
	cd firmware/libc && make
	cd firmware/librender && make
ifneq ($(JAVAC),)
	cd tools/visualizer && make
endif

	
test: all FORCE
	cd tests/cosimulation && ./runtest.sh *.s
	
clean:
	cd tools/simulator && make clean
	cd tools/mkbmp && make clean
	cd firmware/libc && make clean
	cd firmware/librender && make clean
	cd rtl/ && make clean
	rm -rf bin/

FORCE:

