

all:
	cd tools/asm && make
	cd tools/disassemble && make
	cd tools/emulator && make
	cd verilog && make
	
clean:
	cd tools/asm && make clean
	cd tools/disassemble && make clean
	cd tools/emulator && make clean
	cd verilog && make clean

