This is a Nyuzi architecture emulator. It is not cycle accurate, and does not 
simulate the behavior of the pipeline or caches, but is useful for several
purposes:

- As a reference for co-verification.  When invoked in cosimulation mode 
(`-m cosim`), it reads instruction side effects from the hardware model 
via stdin. It steps its own threads and compare the results, flagging 
an error if they do not match. More details are in the README file in
the tests/cosimulation directory.
- For development of software.  This allows attaching a symbolic debugger 
(described below).
- Performance modeling. This can generate memory reference traces and gather
statistics about instruction execution.

Command line options:

|Option|Arguments                  |Meaning|
|------|---------------------------|-------|
| -v |                             | Verbose, prints register transfers to stdout |
| -m | mode                        | Mode is one of: |
|    |                             | normal- Run to completion (default) |
|    |                             | cosim- Cosimulation validation mode |
|    |                             | gdb - Allow debugger connection on port 8000 |
| -f |  widthxheight               | Display framebuffer output in window |
| -d |  filename,start,length      | Dump memory (start and length are hex) |
| -b |  filename                   | Load file into virtual block device |
| -t |  num                        | Total threads (default 4) |
| -c |  size                       | Total amount of memory (size is hex)|
| -r |  instructions               | Screen refresh rate, number of instructions to execute between screen updates |

A few other notes:

- System memory starts at address 0. The emulator loads the passed memory image
  file (in the hexadecimal format that the Verilog $readmemh task uses) starting
  at the beginning of memory, and starts execution at address 0. The elf2hex 
  utility, included with the toolchain, produces a hex file from an ELF file. 
- The simulation exits when all threads halt (by writing to the appropriate 
  control registers)
- Uncommenting the line `CFLAGS += -DLOG_INSTRUCTIONS=1` in the Makefile 
  causes it to dump instruction statistics.
- See rtl/README.md for list of device registers supported. The emulator doesn't
support the following devices:
  * LED/HEX display output registers
  * Serial RX
  * VGA frame buffer/toggle
  * SPI GPIO mode
 
### Debugging with LLDB

LLDB is a symbolic debugger built as part of the toolchain. Documentation
is available [here](http://lldb.llvm.org/tutorial.html). To use this,
you must compile the program with debug information enabled (the -g flag).
Many app makefiles have a 'debug' target that will start this automatically.
The steps to run the debugger manually are:

1. Start emulator in GDB mode

        emulator -m gdb <program>.hex

2. Start LLDB and attach to emulator. It should be in the directory that you 
  built the program in, so it can find sources.

        /usr/local/llvm-nyuzi/bin/lldb --arch nyuzi <program>.elf -o "gdb-remote 8000"

Other notes:
- This is new and still has bugs and missing functionality.  
- Does not support writing memory (or operations that require it)
- You cannot run the debugger cannot while the emulator is in cosimulation mode.
- Debugging works better if you compile the program with optimizations disabled.
For example, at -O3, lldb cannot read variables if they are not live at the 
execution point. 

### Look up line numbers

You can convert a program address can to a file/line combination with the 
llvm-symbolizer program. This is not installed by default, but is in the 
build directory for the toolchain:

    echo <address> | <path to toolchain source directory>/build/bin/llvm-symbolizer -demangle -obj=<program>.elf

### Tracing

Another way of debugging is to enable verbose instruction logging. Change the 
commandline to add the -v parameter:

    bin/emulator -v program.hex

This dumps every memory and register transfer to the console. 

Many test programs have a target to build the list file, but you can create 
one like this:

    /usr/local/llvm-nyuzi/bin/llvm-objdump --disassemble program.elf > program.lst 2> /dev/null

You can correlate the trace...

    ```
    0000f43c [st 0] s0 <= 00010000
    0000f428 [st 1] s0 <= 00000001
    0000f414 [st 2] writeMemWord 000f7a74 00000000
    0000f400 [st 3] s0 <= 3e8a867a
    0000f440 [st 0] s30 <= 0000f444
    ```

...with the listing to understand how the program is operating.

    ```
    f428:    00 04 80 07                                      move s0, 1
    f42c:    1d 20 14 82                                      store_8 s0, 1288(sp)
    f430:    60 03 00 ac                                      getcr s27, 0
    f434:    5b 03 80 08                                      setne_i s26, s27, 0
    f438:    1a 02 00 f4                                      btrue s26, main+772
    f43c:    1f b0 ef a9                                      load_32 s0, -1044(pc)
    ```
