#!/usr/bin/env bash

LOCAL_TOOLS_DIR=../../tools
COMPILER_DIR=/usr/local/llvm-vectorproc/bin
VERILATOR=../../rtl/obj_dir/Vverilator_tb
CC=$COMPILER_DIR/clang
LD=$COMPILER_DIR/lld
AS=$COMPILER_DIR/llvm-mc
ELF2HEX=$COMPILER_DIR/elf2hex
ASFLAGS="-filetype=obj"
CFLAGS="-c -fno-inline"
LDFLAGS="-flavor gnu -static"
HEXFILE=WORK/program.hex
ELFFILE=WORK/program.elf

mkdir -p WORK

function compileAndRun {
	# Build
	$AS $ASFLAGS -o WORK/start.o start.s
	$CC $CFLAGS -O3 -c $1 -o WORK/$1.o
	$LD $LDFLAGS WORK/start.o WORK/$1.o -o $ELFFILE
	$ELF2HEX $HEXFILE $ELFFILE
	
	# Run, collect results
	echo "running $1"
	$VERILATOR +bin=WORK/program.hex | awk '/ran for/{ print 1048576 / $3 " bytes/cycle" }'
}

compileAndRun 'read_test.cpp'
compileAndRun 'write_test.cpp'
compileAndRun 'copy_test.cpp'
