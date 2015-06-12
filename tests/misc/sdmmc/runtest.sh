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
COPY_SIZE=2	# in kilobytes

mkdir -p WORK

# Create a file with random contents. Linux needs the fullblock flag
# or it will create a short file.  Darwin has an older version of dd
# that doesn't support the flag, but the default behavior is to write
# full blocks.
case "$(uname -s)" in
	Darwin)
		dd if=/dev/random of=bdevimage.bin bs=1024 count=$COPY_SIZE
		;;
	
	*)
		dd iflag=fullblock if=/dev/random of=bdevimage.bin bs=1024 count=$COPY_SIZE
		;;
esac		
		

$CC -O3 -o $ELFFILE sdmmc.c ../../../software/libs/libc/crt0.o  $LIBS $INCS
$ELF2HEX -o $HEXFILE $ELFFILE

#
# Run test in emulator
#

echo "*** Testing in emulator ***"
$EMULATOR -b bdevimage.bin -demumem.bin,200000,800 $HEXFILE 
diff bdevimage.bin emumem.bin
if [ $? -ne 0 ]
then
	echo "FAIL: simulator final memory contents do not match"
	exit 1
fi

# 
# Run test in Verilog simulation
#
echo "*** Testing with Verilator ***"
$VERILATOR +block=bdevimage.bin +autoflushl2=1 +memdumpfile=verimem.bin +memdumpbase=200000 +memdumplen=800 +bin=$HEXFILE 
diff bdevimage.bin verimem.bin
if [ $? -ne 0 ]
then
	echo "FAIL: verilator final memory contents do not match"
	exit 1
fi

echo "PASS"

