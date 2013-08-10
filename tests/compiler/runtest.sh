#!/bin/sh

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
ISS=$LOCAL_TOOLS_DIR/simulator/iss
CC=$COMPILER_DIR/clang
LD=$COMPILER_DIR/lld
AS=$COMPILER_DIR/llvm-mc
FLATTEN=$LOCAL_TOOLS_DIR/flatten_elf/flatten_elf
ASFLAGS="-filetype=obj -triple vectorproc-elf"
CFLAGS="-c -integrated-as -target vectorproc -fno-inline"
LDFLAGS="-flavor gnu -target vectorproc  -static"
HEXFILE=WORK/program.hex
ELFFILE=WORK/program.elf

mkdir -p WORK

$AS $ASFLAGS -o WORK/start.o start.s
PASSED=1

for sourcefile in "$@"
do
	for optlevel in "-O0" "-O3"
	do
		echo "Testing $sourcefile at $optlevel"
		$CC $CFLAGS $optlevel -c $sourcefile -o WORK/$sourcefile.o
		if [ $? -ne 0 ]
		then
			PASSED=0
			continue
		fi

		$LD $LDFLAGS WORK/start.o WORK/$sourcefile.o -o $ELFFILE
		if [ $? -ne 0 ]
		then
			PASSED=0
			continue
		fi

		$FLATTEN $HEXFILE $ELFFILE
		$ISS $HEXFILE | ./checkresult.py $sourcefile 
		if [ $? -ne 0 ]
		then
			PASSED=0
		fi
	done
done

if [ $PASSED -ne 0 ]
then
	echo "All tests passed"
else
	echo "Some tests failed"
fi
