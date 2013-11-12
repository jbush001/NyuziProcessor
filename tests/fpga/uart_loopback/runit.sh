#!/bin/sh

../../../tools/assembler/assemble -o uart_loopback.hex uart_loopback.asm
jload uart_loopback.hex
