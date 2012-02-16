#!/bin/bash

cpp < rasterize.asm > /tmp/rasterize.pasm
../tools/asm/assemble -o program.hex /tmp/rasterize.pasm
if [ $? -eq 0 ];then
    vvp ../verilog/sim.vvp +bin=program.hex +dumpfb=rawfb.ppm +simcycles=1000000 +trace=trace.vcd
fi

