
TOOLDIR=/usr/local/llvm-vectorproc/bin
CC=$(TOOLDIR)/clang
ELF2HEX=$(TOOLDIR)/elf2hex
CFLAGS=-O3 -ffreestanding

boot.hex: boot.c start.s
	$(CC) $(CFLAGS) boot.c start.s -o boot.elf
	$(ELF2HEX) -o boot.hex boot.elf

run: boot.hex
	jload boot.hex

clean: FORCE
	rm -f boot.elf boot.hex

FORCE:

