
TOOLDIR=/usr/local/llvm-vectorproc/bin
CC=$(TOOLDIR)/clang
LD=$(TOOLDIR)/lld
AS=$(TOOLDIR)/llvm-mc
ELF2HEX=$(TOOLDIR)/elf2hex
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
	$(ELF2HEX) $@ texture.elf

run: texture.hex
	jload texture.hex

runsim: texture.hex
	vvp ../../../rtl/fpga-sim.vvp  +bin=texture.hex -lxt2 +regtrace=1

main.o: main.cpp
start.o: start.s
util.o: util.s

clean: FORCE
	rm -f $(OBJS) texture.hex texture.elf

FORCE:

