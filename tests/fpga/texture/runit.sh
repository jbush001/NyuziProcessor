#!/bin/sh

../../../tools/assembler/assemble -o texture.hex texture.asm
jload texture.hex
#vvp ../../../rtl/fpga-sim.vvp  +bin=texture.hex -lxt2
