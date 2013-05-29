#!/bin/sh

../../../tools/assembler/assemble -o mandelbrot.hex mandelbrot.asm
jload mandelbrot.hex
#vvp ../../../rtl/fpga-sim.vvp  +bin=mandelbrot.hex -lxt2
