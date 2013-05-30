#!/bin/sh

../../../tools/assembler/assemble -o uart.hex uart.asm
jload uart.hex
#vvp ../../../rtl/fpga-sim.vvp  +bin=uart.hex -lxt2
