#!/bin/sh

../../../tools/assembler/assemble -o threads.hex threads.asm
jload threads.hex

