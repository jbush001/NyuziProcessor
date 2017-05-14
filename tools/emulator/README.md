This is a Nyuzi instruction set emulator. It is not cycle accurate, and does not
simulate the behavior of the pipeline or caches, but is useful for several
purposes:

- As a reference for co-verification.  When invoked in cosimulation mode
(`-m cosim`), it reads instruction side effects from the hardware model
via stdin. It steps its own threads and compare the results, flagging
an error if they do not match. More details are in tests/cosimulation/README.md
directory.
- For development of software.  This allows attaching a symbolic debugger
(described below).
- Performance modeling. This can generate memory reference traces and gather
statistics about instruction execution.

This also simulates hardware peripherals supported by the FPGA and Verilog
simulator environments (which are all software compatible), such as video
output and a mass storage device.

### Command line options:

|Option|Arguments                  |Meaning                                           |
|------|---------------------------|--------------------------------------------------|
| -v   |                           | Verbose, prints register transfers to stdout     |
| -m   |  mode                     | Mode is one of:                                  |
|      |                           | normal- Run to completion (default)              |
|      |                           | cosim- Cosimulation validation mode              |
|      |                           | gdb - Allow debugger connection on port 8000     |
| -f   |  widthxheight             | Display framebuffer output in window             |
| -d   |  filename,start,length    | Dump memory                                      |
| -b   |  filename                 | Load file into virtual block device              |
| -t   |  num                      | Threads per core (default 4)                     |
| -p   |  num                      | Number of cores (default 1)                      |
| -c   |  size                     | Total amount of memory                           |
| -r   |  instructions             | Screen refresh rate, number of instructions to execute between screen updates |
| -s   |  filename                 | Create the file and map emulated system memory onto it as a shared memory object |
| -i   |  filename                 | The passed filename is expected to be a named pipe. When bytes are sent over this pipe, it will emulate an external interrupt with the index in the byte. |
| -o   |  filename                 | The passed filename is expected to be a named pipe. Writing to the host interrupt register will send the 8-bit ID over the pipe. |

The simulator assumes numeric arguments are decimals unless they are prefixed
with '0x', in which case it interprets them hexadecimal.

Other notes:

- Printfs from the emulated software will be written to the emulator standard
  out (via the virtual UART register)
- Memory starts at address 0. The emulator loads the memory image file (in the
  hexadecimal format that the Verilog $readmemh task uses) passed on the
  command line. It starts execution at address 0. The elf2hex utility, included
  with the toolchain, produces the hex file from an ELF file.
- The simulation exits when all threads halt (by writing to the appropriate
  control registers)
- Uncommenting the line `CFLAGS += -DLOG_INSTRUCTIONS=1` in the Makefile
  causes it to dump instruction statistics.
- See [SOC-Test-Environment](https://github.com/jbush001/NyuziProcessor/wiki/SOC-Test-Environment)
  for list of supported device registers. The emulator doesn't support the following devices:
  * LED/HEX display output registers
  * Serial reads
  * VGA frame buffer address/toggle
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
- The emulator does not support the debugger in cosimulation mode.
- Debugging works better if you compile the program with optimizations disabled.
  For example, at -O3, lldb cannot read variables if they are not live at the
  execution point.
- The debugger does not work with virtual memory enabled.

It should be possible to use any GUI debugger that works with the GDB/MI
protocol, such as [Eclipse](https://eclipse.org/) or Emacs using the
lldb-mi executable that is installed with the toolchain, but I have not
tested this. There are some instructions
[here](https://www.codeplay.com/portal/lldb-mi-driver---part-2-setting-up-the-driver),
which would need to be adapted to this environment.

### Tracing

Another way of debugging is to enable verbose instruction logging. Change the
commandline to add the -v parameter:

    bin/emulator -v program.hex

This dumps every memory and register transfer to the console.

Many test programs have a target to build the list file, but you can create
one like this:

    /usr/local/llvm-nyuzi/bin/llvm-objdump -d -S program.elf > program.lst 2> /dev/null

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
    f438:    1a 02 00 f4                                      bnz s26, main+772
    f43c:    1f b0 ef a9                                      load_32 s0, -1044(pc)
    ```

### Look up line numbers

You can convert a program address can to a file/line combination with the
llvm-symbolizer program. This is not installed by default, but is in the
build directory for the toolchain:

    echo <address> | <path to toolchain source directory>/build/bin/llvm-symbolizer -demangle -obj=<program>.elf

