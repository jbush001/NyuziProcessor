#!/bin/sh

../../../tools/assembler/assemble -o blinky.hex blinky.asm
jload blinky.hex

