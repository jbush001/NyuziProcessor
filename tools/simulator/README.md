This is a instruction accurate functional simulator for this instruction set.  It is not
cycle accurate, and it does not simulate the behavior of caches. It can run in a few
different modes, specified with the -m &lt;mode&gt; flag:
- cosim - co-simulation mode. The simulator reads instruction side effects from stdin (which 
are produced by the Verilog model) and verifies they are correct given the program.
- debug - Allows single step, breakpoints, etc.
- gui - (Mac only) Pops up a window that displays the live contents of the framebuffer
- gdb - (in development) Allow a debugger to attach with remote GDB protocol to port 8000.
- &lt;default&gt; Executes program until the processor is halted.

The simulator expects a memory image as input, encoded in hexadecimal in a format that is 
consistent with that expected by the Verilog $readmemh.  This can be produced from an ELF
file by using the elf2hex utility included with the toolchain project.

The simulation will exit when all threads are halted (disabled using control registers)

When the simulation is finished, it can optionally dump memory with the -d option, which takes 
parameters filename,start,length

Adding the -v (verbose) flag will dump all register and memory transfers to standard out.

The simulator allocates memory to the virtual machine, starting at address 0.

### Interactive Debugger commands
|name|description
|----|----
| regs | Display the values of all scalar and vector registers
| step | Execute one instruction
| resume | Begin running the program
| delete-breakpoint &lt;pc&gt; | Remove a breakpoint at the given code address
| set-breakpoint &lt;pc&gt; | Set a breakpoint at the passed PC
| breakpoints | List all active breakpionts
| read-memory &lt;address&gt; &lt;length&gt; | Display a hexdump of memory from the given address
| strand [id] | If ID is specified, sets the active strand to that ID.  If no ID is passed, displays active strand ID
| quit | Exit simulator

### Debugging with LLDB (in development)

LLDB is a symbolic debugger built as part of the toolchain. It's currently not fully functional. 
In order to use this:

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
