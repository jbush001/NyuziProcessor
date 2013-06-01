#!/bin/sh

../../../tools/assembler/assemble -o load_image.hex load_image.asm
jload load_image.hex
#vvp ../../../rtl/fpga-sim.vvp  +bin=load_image.hex -lxt2
