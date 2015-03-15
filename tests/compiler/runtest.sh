#!/bin/bash
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


BINDIR=../../bin
COMPILER_DIR=/usr/local/llvm-nyuzi/bin
EMULATOR=$BINDIR/emulator
CC=$COMPILER_DIR/clang
ELF2HEX=$COMPILER_DIR/elf2hex
ELFFILE=WORK/program.elf
HEXFILE=WORK/program.hex
CFLAGS="-I../../software/libc/include -w"
LIBS="../../software/libc/libc.a"

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
		$CC $CFLAGS ../../software/libc/crt0.o $sourcefile $LIBS -O3 -o $ELFFILE 
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
    		$CC $CFLAGS ../../software/libc/crt0.o $sourcefile $LIBS $optlevel -o $ELFFILE 
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
