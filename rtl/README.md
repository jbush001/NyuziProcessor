This directory contains the hardware implementation of the processor in 
SystemVerilog. There are three directories:
- core/ The GPGPU proper. The top level module is 'nyuzi'.
Configurable options (cache size, associativity, number of cores) are set in 
core/config.sv
- fpga/ Components of a a quick and dirty system-on-chip configuration for testing on FPGA.
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
| +block=&lt;filename&gt; | Read file into virtual block device, which will be exposed as a virtual SD/MMC device.
| +randseed=&lt;seed&gt; | Set the seed for the random number generator used to initialize reset state of signals 
| +dumpmems=1 | Dump the sizes of all internal FIFOs and SRAMs to standard out. Used by tools/misc/extract_mems.py | 

The simulator will exit when all thread are halted (by writing to the
appropriate control register).

To enable a waveform trace, set the environment variable VERILATOR_TRACE before building:

    VERILATOR_TRACE=1 make

The simulator writes a file called `trace.vcd` in "[value change dump](http://en.wikipedia.org/wiki/Value_change_dump)"
format in the current working directory.

The processor exposes the following memory mapped device registers (the 'environment' 
column indicates which environments support it, F = fpga, E = emulator, V = verilator)

|Address|r/w|Environment|Description|
|----|----|----|----|
| ffff0000 | w | F | Set value of red LEDs |
| ffff0004 | w | F | Set value of green LEDs |
| ffff0008 | w | F | Set value of 7 segment display 0 |
| ffff000c | w | F | Set value of 7 segment display 1 |
| ffff0010 | w | F | Set value of 7 segment display 2 |
| ffff0014 | w | F | Set value of 7 segment display 3 |
| ffff0018 | r | FEV | Serial status. Bit 0: bytes in read FIFO. Bit 1: space available in write FIFO |
| ffff001c | r | F | Serial read register |
| ffff0020 | w | FEV | Serial write register<sup>1</sup> |
| ffff0028 | w | F | VGA frame buffer address |
| ffff002c | r | F | VGA frame toggle register |
| ffff0038 | r | FEV | PS/2 Keyboard status. 1 indicates there are scancodes in FIFO. |
| ffff003c | r | FEV | PS/2 Keyboard scancode. Remove from FIFO on read.<sup>2</sup> |
| ffff0044 | w | FEV | SD SPI write byte<sup>3</sup> |
| ffff0048 | r | FEV | SD SPI read byte |
| ffff004c | r | FEV  | SD SPI status (bit 0: ready) |
| ffff0050 | w | FEV | SD SPI control (bit 0: chip select) |
| ffff0054 | w | FV | SD clock divider |
| ffff0058 | w | F | SD GPIO direction<sup>4</sup> |
| ffff005c | w | F | SD GPIO value |

1. Serial writes are printed to standard out in the emulator and Verilator, allowing logging.
2. In the Verilator environment, keyboard scancodes are just an incrementing pattern. For the emulator, they are only returned if the framebuffer window is displayed and in focus. For the FPGA, they use the PS/2 port on the board.
3. SD GPIO and SD SPI are mutually exclusive.  SD GPIO is if BITBANG_SDMMC is set in rtl/fpga/fpga_top.sv, SPI otherwise.
4. SD GPIO pins are mapped as follows:

    |Bit|Connection|
    |----|----|
    | 0 | dat[0] |
    | 1 | dat[1] |
    | 2 | dat[2] |
    | 3 | dat[3] |
    | 4 | cmd |
    | 5 | clk |

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
