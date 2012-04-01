
SRCS=main.asm rasterize.asm geometry.asm

    
program.hex: $(SRCS)
	../tools/asm/assemble -o program.hex $(SRCS)

go: program.hex FORCE
	vvp ../verilog/sim.vvp +bin=program.hex +simcycles=100000 +dumpfb=rawfb.ppm +trace=trace.vcd
	
FORCE:
