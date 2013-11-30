#!/bin/sh

/usr/local/llvm-vectorproc/bin/clang -o memory_test.elf memory_test.S
/usr/local/llvm-vectorproc/bin/elf2hex memory_test.hex memory_test.elf
jload memory_test.hex
