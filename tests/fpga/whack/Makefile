
TOOLDIR=/usr/local/llvm-vectorproc/bin
CC=$(TOOLDIR)/clang
ELF2HEX=$(TOOLDIR)/elf2hex
CFLAGS=-O3

whack.hex: main.cpp start.s
	$(CC) $(CFLAGS) start.s main.cpp -o whack.elf
	$(ELF2HEX) -o whack.hex whack.elf

run: whack.hex
	jload whack.hex

clean: FORCE
	rm -f whack.elf whack.hex

FORCE:

