#!/bin/sh

/usr/local/llvm-vectorproc/bin/clang -o blinky.elf blinky.S
/usr/local/llvm-vectorproc/bin/elf2hex blinky.hex blinky.elf
jload blinky.hex
