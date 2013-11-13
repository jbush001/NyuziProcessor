#!/bin/sh

../../../tools/assembler/assemble -o texture.hex texture.asm
jload texture.hex
