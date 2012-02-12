#!/bin/bash

../tools/asm/assemble -o program.hex rasterize.asm
if [ $? -eq 0 ];then
    vvp ../verilog/sim.vvp +bin=program.hex +dumpfb=rawfb.ppm +simcycles=1000000
fi

