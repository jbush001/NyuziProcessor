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

The simulation will exit when all threads are halted (by disabling using control registers)

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
- Start simulator in GDB mode:

```
simulator -m gdb <program>.hex
```
- Start LLDB and attach to simulator:

```
/usr/local/llvm-nyuzi/bin/lldb --arch nyuzi <program>.elf -o "gdb-remote 8000"
```

