
TOOLDIR=/usr/local/llvm-vectorproc/bin
CC=$(TOOLDIR)/clang
LD=$(TOOLDIR)/lld
AS=$(TOOLDIR)/llvm-mc
FLATTEN=../../../tools/flatten_elf/flatten_elf
ASFLAGS=-filetype=obj -triple vectorproc-elf
CFLAGS=-c -integrated-as -target vectorproc -O3
LDFLAGS=-flavor gnu -target vectorproc  -static --entry=_start

OBJS=main.o start.o util.o

.s.o:
	$(AS) $(ASFLAGS) -o $@ $<
	
.cpp.o:
	$(CC) $(CFLAGS) $< -o $@	

texture.hex: $(OBJS) Barrier.h
	$(LD) $(LDFLAGS) $(OBJS) -o texture.elf
	$(FLATTEN) $@ texture.elf

run: texture.hex
	jload texture.hex

main.o: main.cpp
start.o: start.s
util.o: util.s

clean: FORCE
	rm -f OBJS texture.hex texture.elf

FORCE:

