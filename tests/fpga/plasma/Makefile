
TOOLDIR=/usr/local/llvm-vectorproc/bin
CC=$(TOOLDIR)/clang
LD=$(TOOLDIR)/lld
AS=$(TOOLDIR)/llvm-mc
ELF2HEX=$(TOOLDIR)/elf2hex
ASFLAGS=-filetype=obj -triple vectorproc-elf
CFLAGS=-c -integrated-as -target vectorproc -O3
LDFLAGS=-flavor gnu -target vectorproc  -static --entry=_start

plasma.hex: plasma.o start.o
	$(LD) $(LDFLAGS) start.o plasma.o -o plasma.elf
	$(ELF2HEX) plasma.hex plasma.elf

run: plasma.hex
	jload plasma.hex

plasma.o: plasma.cpp
	$(CC) $(CFLAGS) -c plasma.cpp	
	
start.o: start.s
	$(AS) $(ASFLAGS) -o start.o start.s

clean: FORCE
	rm -f start.o plasma.o a.out

FORCE:

