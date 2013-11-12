#!/bin/sh

../../../tools/assembler/assemble -o whack.hex whack.asm
jload whack.hex
