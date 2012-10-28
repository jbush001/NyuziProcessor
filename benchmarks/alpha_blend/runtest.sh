#!/bin/bash

# 
# Copyright 2011-2012 Jeff Bush
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

BASEDIR=../..

mkdir -p WORK
$BASEDIR/tools/assembler/assemble -o WORK/alpha.hex alpha.asm

# Framebuffer is BGRA
# Now that we've assembled the file, put the bitmaps in place
# First write the destination buffer
for (( row = 0; row < 64; row++ ))
do
	for  (( col = 0; col < 64; col++ ))
	do
		printf "0000%02xff\n" $(($row * 4)) >> WORK/alpha.hex	
	done
done

# Then the source buffer, with alpha
for (( row = 0; row < 64; row++ ))
do
	for  (( col = 0; col < 64; col++ ))
	do	
		printf "ff0000%02x\n" $(($col * 4)) >> WORK/alpha.hex
	done
done

vvp $BASEDIR/rtl/sim.vvp +statetrace=statetrace.txt +bin=WORK/alpha.hex +simcycles=20000 +memdumpbase=400 +memdumplen=4000 +memdumpfile=WORK/fb.bin
#$BASEDIR/tools/emulator/emulator -d WORK/fb.bin,400,4000 WORK/alpha.hex 
$BASEDIR/tools/mkbmp/mkbmp WORK/fb.bin vsim.bmp 64 64
