This is an emulator for the Nyuzi architecture. It is not cycle accurate, and 
it does not simulate the behavior of the pipeline or caches. It is used in 
a number of ways:

- As a reference for co-verification.  When invoked in cosimulation mode 
(`-m cosim`), it will read instruction side effects from the hardware model 
via stdin. It will then step its own threads and compare the results, flagging 
an error if they do not match. More details are in the tests/cosimulation 
directory.
- For development of software.  This allows optionally attaching a symbolic 
debugger (described below).

A few other notes:

- The emulator maps system memory starting at address 0. This must be initialized 
with a memory image, encoded in hexadecimal in a format that is consistent with that 
expected by the Verilog $readmemh. This can be produced from an ELF file by using the 
elf2hex utility included with the toolchain project. The memory layout in the emulator
differs from that used on FPGA.
- The simulation will exit when all threads are halted (disabled using control 
registers)
- When the simulation is finished, it can optionally dump memory with the -d 
option
- The -f flag will open a framebuffer window (assumed to be 32-bpp at 
memory address 0x200000).  
- By default this runs with four threads, but the number can be increased to 
simulate an arbitrary number of cores with the -t flag.
- Uncommenting the line `CFLAGS += -DLOG_INSTRUCTIONS=1` in the Makefile will 
cause it to dump detailed instruction statistics.

### Debugging with LLDB (in development)

LLDB is a symbolic debugger built as part of the toolchain. In order to use this:

- Program must be compiled with debug information (-g)
- Start emulator in GDB mode.

```
emulator -m gdb <program>.hex
```
- Start LLDB and attach to emulator.  This will need to be done in a different 
terminal and should be in the directory the program under test was built in, so it 
can find sources.

```
/usr/local/llvm-nyuzi/bin/lldb --arch nyuzi <program>.elf -o "gdb-remote 8000"
```

LLDB documentation is available here:

http://lldb.llvm.org/tutorial.html

This is still under development. The following features are currently working:
* Continue/stop
* Breakpoints (set by function name or file/line)
* Single step
* Read memory and registers
* Displaying global variables

These features are not yet working:
* Stack trace (only shows leaf function).  See [here](https://github.com/jbush001/NyuziToolchain/issues/9)
* Displaying local variables

Note also that the debugger cannot be run while the emulator is in cosimulation mode.

### Look up line numbers

A program address can be converted to a file/line combination with the llvm-symbolizer
program. This is not installed by default, but will be in the build directory for
the toolchain:

    echo <address> | <path to toolchain source directory>/build/bin/llvm-symbolizer -demangle -obj=<program>.elf

### Tracing

Another way of debugging is to enable verbose instruction logging. Modify the commandline to add the -v
parameter:

    bin/emulator -v program.hex

This will dump every memory and register transfer to the console. 

Many test programs have a target to build the list file, but one can be created manually:

    /usr/local/llvm-nyuzi/bin/llvm-objdump --disassemble program.elf > program.lst 2> /dev/null

The trace: 

    ```
    0000f43c [st 0] s0 <= 00010000
    0000f428 [st 1] s0 <= 00000001
    0000f414 [st 2] writeMemWord 000f7a74 00000000
    0000f400 [st 3] s0 <= 3e8a867a
    0000f440 [st 0] s30 <= 0000f444
    ```

can be reconcilzed with the listing to understand how the program is operating.

    ```
    f428:	00 04 80 07                                  	move s0, 1
    f42c:	1d 20 14 82                                  	store_8 s0, 1288(sp)
    f430:	60 03 00 ac                                  	getcr s27, 0
    f434:	5b 03 80 08                                  	setne_i s26, s27, 0
    f438:	1a 02 00 f4                                  	btrue s26, main+772
    f43c:	1f b0 ef a9                                  	load_32 s0, -1044(pc)
    ```
    
### Virtual Devices

The emulator exposes the following virtual devices

| address | r/w | description
|----|----|----
| ffff0004 | r | Always returns 0x12345678
| ffff0008 | r | Always returns 0xabcdef9b
| ffff0018 | r | Serial status. Bit 1 indicates space available in write FIFO
| ffff0020 | w | Serial write register (will output to stdout)
| ffff0030 | w | Virtual block device read address
| ffff0034 | r | Read word from virtual block device and increment read address
| ffff0038 | r | Keyboard status. 1 indicates there are scancodes in FIFO.
| ffff003c | r | Keyboard scancode. Remove from FIFO.  Matches PS2 mode set 1
| ffff0040 | r | Real time clock.  Current time in microseconds
