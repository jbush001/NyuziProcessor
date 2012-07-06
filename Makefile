

all:
	cd tools/assembler && make
	cd tools/disassembler && make
	cd tools/emulator && make
	cd tools/mkbmp && make
	cd verilog && make
	
clean:
	cd tools/assembler && make clean
	cd tools/disassembler && make clean
	cd tools/emulator && make clean
	cd tools/mkbmp && make clean
	cd verilog && make clean

