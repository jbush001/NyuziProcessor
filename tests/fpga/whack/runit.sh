#!/bin/sh

../../../tools/assembler/assemble -o whack.hex whack.asm
jload whack.hex
#vvp ../../../rtl/fpga-sim.vvp  +bin=whack.hex -lxt2
