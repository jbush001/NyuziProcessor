
TOOLDIR=/usr/local/llvm-vectorproc/bin
CC=$(TOOLDIR)/clang
ELF2HEX=$(TOOLDIR)/elf2hex
CFLAGS=-O3

bug.hex: main.cpp start.s Barrier.h
	$(CC) $(CFLAGS) main.cpp start.s -o bug.elf
	$(ELF2HEX) -o bug.hex bug.elf

run: bug.hex
	jload bug.hex

clean: FORCE
	rm -f bug.elf bug.hex

FORCE:

