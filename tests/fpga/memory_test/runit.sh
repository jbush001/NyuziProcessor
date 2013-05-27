#!/bin/sh

../../../tools/assembler/assemble -o memory_test.hex memory_test.asm
jload memory_test.hex
#vvp ../../../rtl/fpga-sim.vvp  +bin=memory_test.hex -lxt2
