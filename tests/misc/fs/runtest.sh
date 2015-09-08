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

COMPILER_DIR=/usr/local/llvm-nyuzi/bin
VERILATOR=../../../bin/verilator_model
EMULATOR=../../../bin/emulator
CC=$COMPILER_DIR/clang
ELF2HEX=$COMPILER_DIR/elf2hex
HEXFILE=WORK/program.hex
ELFFILE=WORK/program.elf
LIBS="../../../software/libs/libc/libc.a ../../../software/libs/libos/libos.a"
INCS="-I../../../software/libs/libos/  -I../../../software/libs/libc/include"

mkdir -p WORK

$CC -O3 -o $ELFFILE fs.c ../../../software/libs/libc/crt0.o  $LIBS $INCS
if [ $? -ne 0 ]
then
	echo "FAIL: compiler error"
	exit 1	# Compiler error
fi

$ELF2HEX -o $HEXFILE $ELFFILE
../../../bin/mkfs fsimage.bin test.txt

echo "*** Testing in emulator ***"
$EMULATOR -b fsimage.bin $HEXFILE | grep PASS
if [ $? -ne 0 ]
then
	echo "FAIL"
	exit 1
fi
