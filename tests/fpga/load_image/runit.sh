#!/bin/sh

/usr/local/llvm-vectorproc/bin/clang -o load_image.elf load_image.S
/usr/local/llvm-vectorproc/bin/elf2hex load_image.hex load_image.elf
jload load_image.hex
