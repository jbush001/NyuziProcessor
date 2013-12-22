#!/usr/bin/env bash

COMPILER_DIR=/usr/local/llvm-vectorproc/bin
VERILATOR=../../rtl/obj_dir/Vverilator_tb
CC=$COMPILER_DIR/clang
ELF2HEX=$COMPILER_DIR/elf2hex
HEXFILE=WORK/program.hex
ELFFILE=WORK/program.elf

mkdir -p WORK

function compileAndRun {
	# Build
	$CC -O3 -o $ELFFILE $1 start.s
	$ELF2HEX -o $HEXFILE $ELFFILE

	# Run, collect results
	echo "running $1"
	$VERILATOR +bin=WORK/program.hex | awk '/ran for/{ print 1048576 / $3 " bytes/cycle" }'
}

compileAndRun 'read_test.cpp'
compileAndRun 'write_test.cpp'
compileAndRun 'copy_test.cpp'
