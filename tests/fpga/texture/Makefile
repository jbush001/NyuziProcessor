
TOOLDIR=/usr/local/llvm-vectorproc/bin
CC=$(TOOLDIR)/clang
ELF2HEX=$(TOOLDIR)/elf2hex
CFLAGS=-O3

texture.hex: main.cpp start.s util.s Barrier.h
	$(CC) $(CFLAGS) main.cpp start.s util.s -o texture.elf
	$(ELF2HEX) -o texture.hex texture.elf

run: texture.hex
	jload texture.hex

clean: FORCE
	rm -f texture.elf texture.hex

FORCE:

