
SRCS=main.asm rasterize.asm geometry.asm fill.asm

    
program.hex: $(SRCS)
	../tools/assembler/assemble -o program.hex $(SRCS)

go: program.hex FORCE
	vvp ../verilog/sim.vvp +bin=program.hex +simcycles=100000 +memdumpbase=FC000 +memdumplen=4000 +memdumpfile=rawfb.bin
	../tools/mkbmp/mkbmp rawfb.bin fb.bmp 64 64
	
emulation: program.hex FORCE
	../tools/emulator/emulator -d rawfb.bin,FC000,4000 program.hex 
	../tools/mkbmp/mkbmp rawfb.bin fb.bmp 64 64
	
FORCE:
