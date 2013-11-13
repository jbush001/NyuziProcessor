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
VERILATOR_MODEL=$BASEDIR/rtl/obj_dir/Vverilator_tb

mkdir -p WORK
$BASEDIR/tools/assembler/assemble -o WORK/mandelbrot.hex mandelbrot.asm

$VERILATOR_MODEL +bin=WORK/mandelbrot.hex +memdumpbase=400 +memdumplen=4000 +memdumpfile=WORK/fb.bin
#$BASEDIR/tools/simulator/iss -d WORK/fb.bin,400,4000 WORK/mandelbrot.hex 
$BASEDIR/tools/mkbmp/mkbmp WORK/fb.bin vsim.bmp 64 64
