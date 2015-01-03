This directory contains the hardware implementation of the processor in 
SystemVerilog. There are three directories:
- core/ The GPGPU core itself. The top level module is called 'nyuzi'. 
Configurable options (cache size, associativity, number of cores) are set in 
core/defines.sv
- fpga/ A quick and dirty FPGA testbench that simulates a simple system-on-chip.  
It  includes a SDRAM controller, VGA controller, and an internal AXI interconnect, 
along with some other peripherals like a serial port. 
(more information is [here](https://github.com/jbush001/NyuziProcessor/wiki/FPGA-Implementation-Notes)).
The makefile for the DE2-115 board target is in fpga/de2-115.
- testbench/ Files for cycle-accurate simulation with [Verilator](http://www.veripool.org/wiki/verilator). 
The Makefile will generate an exeutable 'verilator_model' in the bin/ directory. This is heavily 
instrumented with debug features. The Verilog simulation model accepts the following arguments:

   |Argument|Value|
   |--------|-----|
   | +bin=&lt;hexfile&gt; | File to be loaded to simulator memory at boot. Each line contains a 32-bit hex encoded value |
   | +regtrace=1 | Enables dumping of register and memory transfers to standard out.  This is used during cosimulation |
   | +statetrace=1 | Dump thread states each cycle into a file called 'statetrace.txt'.  Used for visualizer app (see tools/visualizer). |
   | +memdumpfile=&lt;filename&gt; | Dump simulator memory to a binary file at the end of simulation. The next two parameters must also be specified for this to work |
   | +memdumpbase=&lt;baseaddress&gt;| Base address in simulator memory to start dumping (hexadecimal) |
   | +memdumplen=&lt;length&gt; | Number of bytes of memory to dump (hexadecimal) |
   | +autoflushl2=1 | If specified, will copy any dirty data in the L2 to system memory at the end of simulation, before dumping to file |
   | +profile=&lt;filename&gt; | Samples the program counters periodically and writes to a file.  Use with tools/misc/profile.py |
   | +block=&lt;filename&gt; | Read file into virtual block device
   | +randseed=&lt;seed&gt; | Set the seed for the random number generator used to initialize reset state of signals
   | +dumpmems=1 | Dump the sizes of all internal FIFOs and SRAMs to standard out | 

   To enable a waveform trace, edit the Makefile and uncomment the line:

       VERILATOR_OPTIONS=--trace --trace-structs

   A .VCD (value change dump) will be written in the directory the model is run from.
   
   The top level testbench exposes a few virtual devices

   | address | r/w | description
   |----|----|----
   | ffff0004 | r | Always returns 0x12345678
   | ffff0008 | r | Always returns 0xabcdef9b
   | ffff0018 | r | Serial status. Bit 1 indicates space available in write FIFO
   | ffff0020 | w | Serial write register (will output to stdout)
   | ffff0030 | w | Virtual block device read address
   | ffff0034 | r | Read word from virtual block device and increment read address


This project uses Emacs verilog mode to automatically generate wire definitions (although it isn't
completely  reliable right now with SystemVerilog).  If you have emacs installed, you can type 
'make autos' from the command line to update the definitions in batch mode.

This design uses parameterized memories (FIFOs and SRAM blocks), however, not all tool flows support
this. This can use hard coded memory instances compatible with memory compilers or SRAM wizards.  
Using `make core/srams.inc` will generate an include file with all used memory sizes in the design.
The script tools/misc/extract_mems.py can be tweaked to change the module names or parameter formats.

