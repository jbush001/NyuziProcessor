
TOOLDIR=/usr/local/llvm-vectorproc/bin
CC=$(TOOLDIR)/clang
LD=$(TOOLDIR)/lld
AS=$(TOOLDIR)/llvm-mc
FLATTEN=../../../tools/flatten_elf/flatten_elf
ASFLAGS=-filetype=obj -triple vectorproc-elf
CFLAGS=-c -integrated-as -target vectorproc 
LDFLAGS=-flavor gnu -target vectorproc  -static

program: main.o start.o
	$(LD) $(LDFLAGS) start.o main.o -o hello.elf
	$(FLATTEN) hello.bin hello.elf

main.o: main.c
	$(CC) $(CFLAGS) -c main.c 	
	
start.o: start.s
	$(AS) $(ASFLAGS) -o start.o start.s

clean: FORCE
	rm start.o main.o a.out

FORCE:

