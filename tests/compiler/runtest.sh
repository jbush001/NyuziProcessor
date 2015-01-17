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
EMULATOR=$BINDIR/emulator
CC=$COMPILER_DIR/clang
ELF2HEX=$COMPILER_DIR/elf2hex
ELFFILE=WORK/program.elf
HEXFILE=WORK/program.hex
CFLAGS="-I../../software/libc/include -w"
LIBS="../../software/libc/libc.a ../../software/libos/libos.a"

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
    if [[ $sourcefile == "_"* ]]
    then
        continue    # Skip disabled tests
    fi
    
	if [ "$USE_HOSTCC" ]
	then
		echo -n "testing $sourcefile (hostcc) "
		c++ $CFLAGS $sourcefile -O3 -o WORK/a.out	
		WORK/a.out | ./checkresult.py $sourcefile 
    	if [ $? -ne 0 ]
    	then
    		tests_failed=$[tests_failed + 1]
    	else
    		tests_passed=$[tests_passed + 1]
    	fi
    elif [ "$USE_VERILATOR" ]
    then
        if [[ $sourcefile == *"noverilator"* ]] 
        then
            # meteor-contest is a great compiler test, but takes forever to
            # run in verilator. Skip it.
            continue  
        fi
        
        # Use hardware model
		echo -n "testing $sourcefile (verilator) "
		$CC $CFLAGS ../../software/libos/crt0.o $sourcefile $LIBS -O3 -o $ELFFILE 
		if [ $? -ne 0 ]
		then
			tests_failed=$[tests_failed + 1]
			continue
		fi

		$ELF2HEX -o $HEXFILE $ELFFILE
		$BINDIR/verilator_model +bin=$HEXFILE | ./checkresult.py $sourcefile 
    	if [ $? -ne 0 ]
    	then
    		tests_failed=$[tests_failed + 1]
    	else
    		tests_passed=$[tests_passed + 1]
    	fi
	else
        # Use emulator. Test at a few different optimization levels.
    	for optlevel in "-O0" "-Os" "-O3" 
    	do
    		echo -n "testing $sourcefile at $optlevel (emulator) "
    		$CC $CFLAGS ../../software/libos/crt0.o $sourcefile $LIBS $optlevel -o $ELFFILE 
    		if [ $? -ne 0 ]
    		then
    			tests_failed=$[tests_failed + 1]
    			continue
    		fi

    		$ELF2HEX -o $HEXFILE $ELFFILE
			$EMULATOR $HEXFILE | ./checkresult.py $sourcefile 
        	if [ $? -ne 0 ]
        	then
        		tests_failed=$[tests_failed + 1]
        	else
        		tests_passed=$[tests_passed + 1]
        	fi
        done
	fi
done

echo "$tests_passed Passed $tests_failed Failed"
