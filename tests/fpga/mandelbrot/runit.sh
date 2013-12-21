#!/bin/sh

/usr/local/llvm-vectorproc/bin/clang -o mandelbrot.elf mandelbrot.S
/usr/local/llvm-vectorproc/bin/elf2hex -o mandelbrot.hex mandelbrot.elf
jload mandelbrot.hex
