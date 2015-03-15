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
VERILATOR=$BINDIR/verilator_model
CC=$COMPILER_DIR/clang
ELF2HEX=$COMPILER_DIR/elf2hex
HEXFILE=WORK/program.hex
ELFFILE=WORK/program.elf

mkdir -p WORK

function compileAndRun {
	# Build
	$CC -O3 -o $ELFFILE $1 ../../software/libc/crt0.o -I../../software/libc/include
	$ELF2HEX -o $HEXFILE $ELFFILE

	# Run, collect results
	echo "running $1"
	$VERILATOR +bin=WORK/program.hex | awk '/ran for/{ print $3 / 256 " cycles/hash" }'
}

compileAndRun 'hash.cpp'

