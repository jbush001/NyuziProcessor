#!/bin/bash

# 
# Copyright 2011-2013 Jeff Bush
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

LOCAL_TOOLS_DIR=../../tools
COMPILER_DIR=/usr/local/llvm-vectorproc/bin
SIMULATOR=$LOCAL_TOOLS_DIR/simulator/iss
CC=$COMPILER_DIR/clang
ELF2HEX=$COMPILER_DIR/elf2hex
ELFFILE=WORK/program.elf
HEXFILE=WORK/program.hex

mkdir -p WORK

tests_passed=0
tests_failed=0

if [ "$#" == "0" ]
then
	checkfiles="*.cpp"
else
	checkfiles="$@"
fi

for sourcefile in $checkfiles
do
	for optlevel in "-O0" "-O3 -fno-inline"
	do
		echo "Testing $sourcefile at $optlevel"
		$CC start.s $sourcefile $optlevel -o $ELFFILE 
		if [ $? -ne 0 ]
		then
			tests_failed=$[tests_failed + 1]
			continue
		fi

		$ELF2HEX $HEXFILE $ELFFILE
		$SIMULATOR $HEXFILE | ./checkresult.py $sourcefile 
		if [ $? -ne 0 ]
		then
			tests_failed=$[tests_failed + 1]
		else
			tests_passed=$[tests_passed + 1]
		fi
	done
done

echo "$tests_passed Passed $tests_failed Failed"
