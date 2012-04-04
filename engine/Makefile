
SRCS=main.asm rasterize.asm geometry.asm fill.asm

    
program.hex: $(SRCS)
	../tools/assembler/assemble -o program.hex $(SRCS)

go: program.hex FORCE
	vvp ../verilog/sim.vvp +bin=program.hex +simcycles=100000 +dumpfb=rawfb.ppm
	
FORCE:
