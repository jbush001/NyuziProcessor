This is a instruction accurate functional simulator for this instruction set.  It is not
cycle accurate, and it does not simulate the behavior of the pipeline or caches. It can 
run in a few different modes, specified with the -m flag:
- cosim - co-simulation mode. The simulator reads instruction side effects from stdin
 (which are produced by the Verilog model) and verifies they match its own execution.
 More details are in the tests/cosimulation directory.
- gdb - (in development) Allow a debugger to attach with remote GDB protocol to port 8000.
- &lt;default&gt; Executes program until the processor is halted.

The simulator expects a memory image as input, encoded in hexadecimal in a format that is 
consistent with that expected by the Verilog $readmemh.  This can be produced from an ELF
file by using the elf2hex utility included with the toolchain project.

The simulation will exit when all threads are halted (disabled using control registers)

When the simulation is finished, it can optionally dump memory with the -d option, which 
takes parameters filename,start,length

Adding the -v (verbose) flag will dump all register and memory transfers to standard out.

The -f flag will open a framebuffer window (assumed to be 32-bpp, 640x480 at 0x200000)

The simulator allocates 16MB of memory to the virtual machine, starting at address 0.

Uncommenting the line `CFLAGS += -DLOG_INSTRUCTIONS=1` in the Makefile will cause this
to dump detailed instruction statistics.

### Debugging with LLDB (in development)

LLDB is a symbolic debugger built as part of the toolchain. In order to use this:

- Program must be compiled with debug information (-g)
- Start simulator in GDB mode.

```
simulator -m gdb <program>.hex
```
- Start LLDB and attach to simulator.  This will need to be done in a different terminal and
should be in the directory the program under test was built in, so it can find sources.

```
/usr/local/llvm-nyuzi/bin/lldb --arch nyuzi <program>.elf -o "gdb-remote 8000"
```

This can be done automatically with the 'run_debugger.sh' script.

LLDB documentation is available here:

http://lldb.llvm.org/tutorial.html

This is still under development. The following features are currently working:
* Continue/stop
* Breakpoints (set by function name or file/line)
* Single step
* Read memory and registers

These features are not yet working:
* Stack trace (only shows leaf function)

Note also that the debugger cannot be run while the simulator is in cosimulation mode.

### Tracing

Another way of debugging is to enable verbose instruction logging.  In the Makefile, 
under the run target, add -v to the parameters for the SIMULATOR command. 

    bin/simulator -v program.hex

This will dump every memory and register transfer to the console. Many programs
already create a .lst file when they are built, but one can be created manually:

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

The simulator exposes a few virtual devices

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
