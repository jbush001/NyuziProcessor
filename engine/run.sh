#!/bin/bash

cpp render.asm > /tmp/render.pasm
../tools/asm/assemble -o program.hex /tmp/render.pasm
if [ $? -eq 0 ];then
    vvp ../verilog/sim.vvp +bin=program.hex +dumpfb=rawfb.ppm +simcycles=1000000 +trace=trace.vcd
fi

