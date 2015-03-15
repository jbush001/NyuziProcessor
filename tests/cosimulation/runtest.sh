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
TOOLCHAIN_DIR='/usr/local/llvm-nyuzi/bin/'
COMPILE=$TOOLCHAIN_DIR/clang
ELF2HEX=$TOOLCHAIN_DIR/elf2hex
EMULATOR=$BINDIR/emulator
VERILATOR_MODEL=$BINDIR/verilator_model
VERILATOR_ARGS="+regtrace=1 +simcycles=2000000 +memdumpfile=WORK/vmem.bin +memdumpbase=0 +memdumplen=A0000 +autoflushl2=1"
if [ "$RANDSEED" ]
then
	VERILATOR_ARGS="$VERILATOR_ARGS +randseed=$RANDSEED"
fi

mkdir -p WORK

for test in "$@"
do
	if [ "${test##*.}" != 'hex' ]
	then
		echo "Building $test"
		PROGRAM=WORK/test.hex
		$COMPILE -o WORK/test.elf $test
		if [ $? -ne 0 ]
		then
			exit 1
		fi

    	$ELF2HEX -o $PROGRAM WORK/test.elf
		if [ $? -ne 0 ]
		then
			exit 1
		fi
	else
		echo "Executing $test"
		PROGRAM=$test
	fi

	$VERILATOR_MODEL $VERILATOR_ARGS +bin=$PROGRAM | $EMULATOR $EMULATOR_DEBUG_ARGS -m cosim -d WORK/mmem.bin,0,A0000 $PROGRAM

	if [ $? -eq 0 ]
	then
		diff WORK/vmem.bin WORK/mmem.bin
		if [ $? -eq 0 ]
		then
			echo "PASS"
		else
			VMEM_HEX="$(mktemp -t hexdump)"
			MMEM_HEX="$(mktemp -t hexdump)"
			hexdump WORK/vmem.bin > $VMEM_HEX
			hexdump WORK/mmem.bin > $MMEM_HEX
			diff $VMEM_HEX $MMEM_HEX
			rm $VMEM_HEX $MMEM_HEX
			echo "FAIL: final memory contents do not match"
			exit 1
		fi
	else
		echo "FAIL: emulator flagged error"
		exit 1
	fi
done

