#!/bin/bash
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

BINDIR=../../bin
COMPILER_DIR=/usr/local/llvm-nyuzi/bin
SIMULATOR=$BINDIR/simulator
CC=$COMPILER_DIR/clang
ELF2HEX=$COMPILER_DIR/elf2hex
ELFFILE=WORK/program.elf
HEXFILE=WORK/program.hex
CFLAGS="-I../../software/libc/include -w"
LIBS="../../software/libc/libc.a ../../software/os/os.a"

mkdir -p WORK

tests_passed=0
tests_failed=0

if [ "$#" == "0" ]
then
	checkfiles="*.cpp *.c"
else
	checkfiles="$@"
fi

for sourcefile in $checkfiles
do
	for optlevel in "-O0" "-O3"
	do
		echo -n "Testing $sourcefile at $optlevel"
		if [ "$USE_HOSTCC" ]
		then
			echo " (hostcc)"
			c++ $CFLAGS $sourcefile $optlevel -o WORK/a.out	
			WORK/a.out | ./checkresult.py $sourcefile 
		else
			$CC -g $CFLAGS ../../software/os/crt0.o $sourcefile $LIBS $optlevel -o $ELFFILE 
			if [ $? -ne 0 ]
			then
				tests_failed=$[tests_failed + 1]
				continue
			fi

			$ELF2HEX -o $HEXFILE $ELFFILE
			if [ "$USE_VERILATOR" ]
			then
				# Run using hardware model
				echo " (verilator)"
				$BINDIR/verilator_model +bin=$HEXFILE | ./checkresult.py $sourcefile 
			else
				# Run using functional simulator
				echo " (simulator)"
				$SIMULATOR $HEXFILE | ./checkresult.py $sourcefile 
			fi
		fi

		if [ $? -ne 0 ]
		then
			tests_failed=$[tests_failed + 1]
		else
			tests_passed=$[tests_passed + 1]
		fi
	done
done

echo "$tests_passed Passed $tests_failed Failed"
