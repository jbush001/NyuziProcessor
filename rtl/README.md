This directory contains the hardware implementation of the processor in 
SystemVerilog. There are three directories:
- core/ The GPGPU proper. The top level module is 'nyuzi'.
Configurable options (cache size, associativity, number of cores) are set in 
core/config.sv
- fpga/ Components of a a simple system-on-chip configuration for testing on FPGA.
It includes a SDRAM controller, VGA controller, and an internal AXI interconnect,
along with some other peripherals like a serial port.
(more information is [here](https://github.com/jbush001/NyuziProcessor/wiki/FPGA-Test-Environment)).
The makefile for the DE2-115 board target is in fpga/de2-115.
- testbench/ Files supporting simulation in [Verilator](http://www.veripool.org/wiki/verilator). 

The Makefile in this directory generates an executable 'verilator_model' 
in the bin/ directory. This is instrumented with a number of debug features. 
The Verilog simulation model accepts the following arguments:

|Argument|Value|
|--------|-----|
| +bin=&lt;hexfile&gt; | File to load into simulator memory at address 0. Each line contains a 32-bit little endian hex encoded value. |
| +regtrace=1 | Dump register and memory transfers to standard out.  The cosimulation tests use this to verify operation. |
| +statetrace=1 | Dump thread states each cycle into a file called 'statetrace.txt'.  Used for visualizer app (tools/visualizer). |
| +memdumpfile=&lt;filename&gt; | Dump simulator memory to a binary file at the end of simulation. The next two parameters must also be specified for this to work |
| +memdumpbase=&lt;baseaddress&gt;| Base address in memory to start dumping (hexadecimal) |
| +memdumplen=&lt;length&gt; | Number of bytes of memory to dump (hexadecimal) |
| +autoflushl2=1 | Copy dirty data in the L2 cache to system memory at the end of simulation before writing to file (used with +memdump...) |
| +profile=&lt;filename&gt; | Sample the program counters periodically and write to a file.  Use with tools/misc/profile.py |
| +block=&lt;filename&gt; | Read file into virtual block device
| +randseed=&lt;seed&gt; | Set the seed for the random number generator used to initialize reset state of signals 
| +dumpmems=1 | Dump the sizes of all internal FIFOs and SRAMs to standard out. Used by tools/misc/extract_mems.py | 

The simulator will exit when all thread are halted (by writing to the
appropriate control register).

To enable a waveform trace, edit the Makefile and uncomment the line:

    VERILATOR_OPTIONS=--trace --trace-structs

The simulator writes a file called `trace.vcd` in "[value change dump](http://en.wikipedia.org/wiki/Value_change_dump)"
format in the current working directory.

The top level simulator testbench exposes the following device registers:

| address | r/w | description
|----|----|----
| ffff0004 | r | Always returns 0x12345678
| ffff0008 | r | Always returns 0xabcdef9b
| ffff0018 | r | Serial status. Bit 1 indicates space available in write FIFO
| ffff0020 | w | Serial write register (outputs to stdout)
| ffff0038 | r | Keyboard status. 1 indicates there are scancodes in FIFO.
| ffff003c | r | Keyboard scancode. Remove from FIFO.  
| ffff0044 | w | SD SPI write byte
| ffff0048 | r | SD SPI read byte
| ffff004c | r | SD SPI status (bit 0: ready)
| ffff0050 | w | SD SPI control (bit 0: chip select)
| ffff0054 | w | SD clock divider
| ffff0058 | w | SD GPIO direction 
| ffff005c | w | SD GPIO value

This project uses Emacs verilog mode to automatically generate some wire definitions 
(although it isn't completely reliable right now with SystemVerilog).  If you have 
Emacs installed, type 'make autos' from the command line to update the definitions 
in batch mode.

This design uses parameterized memories (FIFOs and SRAM blocks), while not all 
tool flows support this. This can use hard coded memory instances compatible 
with memory compilers or SRAM wizards. Using `make core/srams.inc` generates 
an include file with all used memory sizes in the design. The script 
tools/misc/extract_mems.py can be tweaked to change the module names or parameter 
formats.
