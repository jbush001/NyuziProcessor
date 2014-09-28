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

COMPILER_DIR=/usr/local/llvm-nyuzi/bin
VERILATOR=../../bin/verilator_model
CC=$COMPILER_DIR/clang
ELF2HEX=$COMPILER_DIR/elf2hex
HEXFILE=WORK/program.hex
ELFFILE=WORK/program.elf

mkdir -p WORK

function compileAndRun {
	# Build
	$CC -O3 -o $ELFFILE $1 start.s
	$ELF2HEX -o $HEXFILE $ELFFILE

	# Run, collect results
	echo "running $1"
	$VERILATOR +bin=WORK/program.hex | awk '/ran for/{ print 1048576 / $3 " bytes/cycle" }'
}

compileAndRun 'read_test.cpp'
compileAndRun 'write_test.cpp'
compileAndRun 'copy_test.cpp'
