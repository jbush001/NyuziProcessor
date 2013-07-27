
#TOOLDIR=/usr/local/llvm-vectorproc/bin
TOOLDIR=~/src/llvm-vectorproc/cmake_build/bin
CC=$(TOOLDIR)/clang
LD=$(TOOLDIR)/lld
AS=$(TOOLDIR)/llvm-mc
FLATTEN=../../../tools/flatten_elf/flatten_elf
ASFLAGS=-filetype=obj -triple vectorproc-elf
CFLAGS=-c -integrated-as -target vectorproc -O3
LDFLAGS=-flavor gnu -target vectorproc  -static --entry=_start

texture.hex: main.o start.o
	$(LD) $(LDFLAGS) start.o main.o -o texture.elf
	$(FLATTEN) texture.hex texture.elf

run: texture.hex
	jload texture.hex

main.o: main.cpp
	$(CC) $(CFLAGS) -c main.cpp	
	
start.o: start.s
	$(AS) $(ASFLAGS) -o start.o start.s

clean: FORCE
	rm -f start.o main.o a.out

FORCE:

