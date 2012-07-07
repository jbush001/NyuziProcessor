
SRCS=main.asm rasterize.asm geometry.asm fill.asm

program.hex: $(SRCS)
	../tools/assembler/assemble -o program.hex $(SRCS)

vsim: FORCE
	vvp ../verilog/sim.vvp +bin=program.hex +simcycles=100000 +memdumpbase=FC000 +memdumplen=4000 +memdumpfile=vsim-fb.bin
	../tools/mkbmp/mkbmp vsim-fb.bin vsim.bmp 64 64
	
cemu: FORCE
	../tools/emulator/emulator -d cemu-fb.bin,FC000,4000 program.hex 
	../tools/mkbmp/mkbmp cemu-fb.bin cemu.bmp 64 64
	
FORCE:

