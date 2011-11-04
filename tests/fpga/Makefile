
hello-world.hex: hello-world.asm
	../../tools/asm/assemble -o hello-world.raw hello-world.asm
	python ../../tools/hexconvert/hexconvert.py -o hello-world.hex -w 32 hello-world.raw
	

