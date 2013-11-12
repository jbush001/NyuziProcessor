#!/bin/sh

../../../tools/assembler/assemble -o uart.hex uart.asm
jload uart.hex
