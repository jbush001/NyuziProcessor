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

ASM=../../tools/assembler/assemble
VMODEL=../../rtl/sim.vvp
ISS=../../tools/simulator/iss

mkdir -p WORK

for test in "$@"
do
	if [ "${test##*.}" != 'hex' ]
	then
		echo "Assembling $test"
		PROGRAM=WORK/test.hex
		$ASM -o $PROGRAM $test
		if [ $? -ne 0 ]
		then
			exit 1
		fi
	else
		echo "Executing $test"
		PROGRAM=$test
	fi
	
	# XXX can add +trace=trace.lxt -lxt2 to dump a waveform
	# Add -v to iss command to see each instruction for both cores on stdout
	
	vvp $VMODEL +regtrace=1 +bin=$PROGRAM +simcycles=30000 +memdumpfile=WORK/vmem.bin +memdumpbase=0 +memdumplen=A0000 +autoflushl2=1 | $ISS -c -d WORK/mmem.bin,0,A0000 $PROGRAM
	if [ $? -eq 0 ]
	then
		diff WORK/vmem.bin WORK/mmem.bin
		if [ $? -eq 0 ]
		then
			echo "PASS"
		else
			echo "FAIL: final memory contents do not match"
			exit 1
		fi
	fi
done

