#!/bin/sh

../../../tools/assembler/assemble -o uart_loopback.hex uart_loopback.asm
#jload uart_loopback.hex
vvp ../../../rtl/fpga-sim.vvp  +bin=uart_loopback.hex -lxt2
