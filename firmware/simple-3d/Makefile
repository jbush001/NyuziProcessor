
BASEDIR=../..
SRCS=main.asm rasterize.asm geometry.asm fill.asm

program.hex: $(SRCS)
	$(BASEDIR)/tools/assembler/assemble -o program.hex $(SRCS)

vsim: program.hex FORCE
	vvp $(BASEDIR)/verilog/sim.vvp +bin=program.hex +simcycles=100000 +memdumpbase=FC000 +memdumplen=4000 +memdumpfile=vsim-fb.bin
	$(BASEDIR)/tools/mkbmp/mkbmp vsim-fb.bin vsim.bmp 64 64
	
cemu: program.hex FORCE
	$(BASEDIR)/tools/emulator/emulator -d cemu-fb.bin,FC000,4000 program.hex 
	$(BASEDIR)/tools/mkbmp/mkbmp cemu-fb.bin cemu.bmp 64 64
	
FORCE:

