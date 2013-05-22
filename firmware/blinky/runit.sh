#!/bin/sh

../../tools/assembler/assemble -o blinky.hex blinky.asm
sudo ~/src/jtag/jload blinky.hex

