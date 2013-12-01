
TOOLDIR=/usr/local/llvm-vectorproc/bin
CC=$(TOOLDIR)/clang
ELF2HEX=$(TOOLDIR)/elf2hex
CFLAGS=-O3

chargen.hex: chargen.c start.s  
	$(CC) $(CFLAGS) chargen.c start.s -o chargen.elf
	$(ELF2HEX) chargen.hex chargen.elf

run: chargen.hex
	jload chargen.hex

clean: FORCE
	rm -f chargen.elf chargen.hex

FORCE:

