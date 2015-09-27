This directory contains the hardware implementation of the processor. There are
three directories: 
- core/ 
  The GPGPU. The top level module is 'nyuzi'. Configurable options (cache size,
  associativity, number of cores) are in core/config.sv
- fpga/ 
  Components of a quick and dirty FPGA system-on-chip test environment. It
  includes an SDRAM controller, VGA controller, AXI interconnect, and other
  peripherals like a serial port. (Documentation is
  [here](https://github.com/jbush001/NyuziProcessor/wiki/FPGA-Test-Environment)). 
  The makefile for the DE2-115 board target is in fpga/de2-115.
- testbench/ 
  Support for simulation in [Verilator](http://www.veripool.org/wiki/verilator).

Typing make in this directory compiles an executable 'verilator_model' in the
bin/ directory. It accepts the following command line arguments:

|Argument|Value|
|--------|-----|
| +bin=&lt;hexfile&gt; | Load this file into simulator memory at address 0. Each line contains a 32-bit little endian hex encoded value. |
| +regtrace | Dump register and memory transfers to standard out.  The cosimulation tests use this to verify operation. |
| +statetrace | Dump thread states each cycle into a file called 'statetrace.txt'.  Used for visualizer app (tools/visualizer). |
| +memdumpfile=&lt;filename&gt; | Dump simulator memory to a binary file at the end of simulation. The next two parameters must also be specified for this to work |
| +memdumpbase=&lt;baseaddress&gt;| Base address in memory to start dumping (hexadecimal) |
| +memdumplen=&lt;length&gt; | Number of bytes of memory to dump (hexadecimal) |
| +autoflushl2 | Copy dirty data in the L2 cache to system memory at the end of simulation before writing to file (used with +memdump...) |
| +profile=&lt;filename&gt; | Periodically write the program counters to a file.  Use with tools/misc/profile.py |
| +block=&lt;filename&gt; | Read file into virtual block device, which it exposes as a virtual SD/MMC device.<sup>1</sup>
| +randomize=&lt;enable&gt; | Randomize initial register and memory values. Used to verify reset handling. Defaults to on.
| +randseed=&lt;seed&gt; | If randomization is enabled, set the seed for the random number generator.
| +dumpmems | Dump the sizes of all internal FIFOs and SRAMs to standard out and exit. Used by tools/misc/extract_mems.py | 

1. The maximum size of the virtual block device is hard coded to 8MB. To 
increase it, change the parameter MAX_BLOCK_DEVICE_SIZE in 
testbench/sim_sdmmc.sv

The amount of RAM available in the Verilog simulator defaults to 16MB. To alter 
it, change MEM_SIZE in testbench/verilator_tb.sv.

The simulator exits when all threads halt by writing to the appropriate control
register.

To write a waveform trace, set the environment variable VERILATOR_TRACE 
and rebuild:

    make clean
    VERILATOR_TRACE=1 make

The simulator writes a file called `trace.vcd` in 
"[value change dump](http://en.wikipedia.org/wiki/Value_change_dump)" 
format in the current working directory.

The processor supports the following memory mapped device registers. The 
'environment' column indicates which environments support it: F = fpga, 
E = emulator, V = verilator.

|Address|r/w|Environment|Description|
|----|----|----|----|
| ffff0000 | w | F | Set value of red LEDs |
| ffff0004 | w | F | Set value of green LEDs |
| ffff0008 | w | F | Set value of 7 segment display 0 |
| ffff000c | w | F | Set value of 7 segment display 1 |
| ffff0010 | w | F | Set value of 7 segment display 2 |
| ffff0014 | w | F | Set value of 7 segment display 3 |
| ffff0018 | r | FEV | Serial status. Bit 0: bytes in read FIFO. Bit 1: space available in write FIFO |
| ffff001c | r | F | Serial read |
| ffff0020 | w | FEV | Serial write<sup>1</sup> |
| ffff0028 | w | F | VGA frame buffer address |
| ffff002c | r | F | VGA frame toggle |
| ffff0038 | r | FEV | PS/2 Keyboard status. 1 indicates there are scancodes in FIFO. |
| ffff003c | r | FEV | PS/2 Keyboard scancode. Remove from FIFO on read.<sup>2</sup> |
| ffff0044 | w | FEV | SD SPI write byte<sup>3</sup> |
| ffff0048 | r | FEV | SD SPI read byte |
| ffff004c | r | FEV  | SD SPI status (bit 0: ready) |
| ffff0050 | w | FEV | SD SPI control (bit 0: chip select) |
| ffff0054 | w | FV | SD clock divider |
| ffff0058 | w | F | SD GPIO direction<sup>4</sup> |
| ffff005c | w | F | SD GPIO value |
| ffff0060 | w | FEV | Thread resume mask. A 1 bit starts a thread. (bit 0 = thread 0) |
| ffff0064 | w | FEV | Thread halt mask. A 1 bit halts a thread. (bit 0 = thread 0) |
| ffff0100 | r | V | Loopback UART Status<sup>5</sup> (same as above) |
| ffff0104 | r | V | Loopback UART read |
| ffff0108 | w | V | Loopback UART write |

1. Serial writes (including printfs from software) print to standard out in
Verilator and the emulator.
2. In the Verilator environment, keyboard scancodes are just an incrementing 
pattern. For the emulator, they are only returned if the framebuffer window is 
displayed and in focus. For the FPGA, they use the PS/2 port on the board. 
3. SD GPIO and SD SPI are mutually exclusive. SD GPIO is if BITBANG_SDMMC is 
set in hardware/fpga/de2_115/de2_115_top.sv, SPI otherwise. 
4. SD GPIO pins map to the following direction/value register bits:

    |Bit|Connection|
    |----|----|
    | 0 | dat[0] |
    | 1 | dat[1] |
    | 2 | dat[2] |
    | 3 | dat[3] |
    | 4 | cmd |
    | 5 | clk |

5. The loopback UART has its transmit and receive signals connected. It's used
for testing the UART implementation.

This project uses Emacs verilog mode to automatically generate some wire
definitions. If you have Emacs installed, type 'make autos' from the command
line to update the definitions in batch mode.

This design uses parameterized memories (FIFOs and SRAM blocks), but not all
tool flows support this. This can use hard coded memory instances compatible
with memory compilers or SRAM wizards. Using `make core/srams.inc` generates an
include file with all used memory sizes in the design. You can tweak the script
tools/misc/extract_mems.py to change the module names or parameter formats.

