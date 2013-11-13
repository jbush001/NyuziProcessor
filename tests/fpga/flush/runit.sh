#!/bin/sh

../../../tools/assembler/assemble -o memory_test.hex memory_test.asm
jload memory_test.hex
