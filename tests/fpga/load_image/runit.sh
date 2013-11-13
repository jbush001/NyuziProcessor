#!/bin/sh

../../../tools/assembler/assemble -o load_image.hex load_image.asm
jload load_image.hex
