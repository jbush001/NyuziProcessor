#!/bin/sh

../../../tools/assembler/assemble -o blinky.hex blinky.asm
#jload blinky.hex
vvp ../../../rtl/fpga-sim.vvp  +bin=blinky.hex -lxt2
