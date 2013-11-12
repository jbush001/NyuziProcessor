#!/bin/sh

../../../tools/assembler/assemble -o mandelbrot.hex mandelbrot.asm
jload mandelbrot.hex
