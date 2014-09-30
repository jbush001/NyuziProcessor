The core is an SoC component with an AXI master interface. The component is called 'gpgpu'.
There are two test configurations:
- A quick and dirty FPGA testbench that simulates a simple SoC.  It includes a SDRAM controller, 
VGA controller, and an internal AXI interconnect, along with some other peripherals like a serial 
port. Most of the components for this are in the fpga/ directory. These are not part of 
the core proper (more information is here 
https://github.com/jbush001/NyuziProcessor/wiki/FPGA-Implementation-Notes).  The makefile for the DE2-115 board
target is in fpga/de2-115.
- A cycle-accurate SystemVerilog simulation model built with verilator. The testbench files
are in the testbench/ directory. It will generate an exeutable 'verilator_model' in the bin/ directory
at the top level. This is heavily instrumented with debug features. The Verilog simulation model accepts 
the following arguments (Verilog arguments begin with a plus sign):

|Argument|Value|
|--------|-----|
| +bin=&lt;hexfile&gt; | File to be loaded to simulator memory at boot. Each line contains a 32-bit hex encoded value |
| +regtrace=1 | Enables dumping of register and memory transfers to standard out.  This is used during cosimulation |
| +statetrace=1 | Dump thread states each cycle into a file called 'statetrace.txt'.  Used for visualizer app (see tools/visualizer). |
| +memdumpfile=&lt;filename&gt; | Dump simulator memory to a binary file at the end of simulation. The next two parameters must also be specified for this to work |
| +memdumpbase=&lt;baseaddress&gt;| Base address in simulator memory to start dumping |
| +memdumplen=&lt;length&gt; | Number of bytes of memory to dump |
| +autoflushl2=1 | If specified, will copy any dirty data in the L2 to system memory at the end of simulation, before dumping to file |
| +profile=&lt;filename&gt; | Each cycle, writes the program counter of the issued instruction to a file.  Use with tools/misc/profile.py |

This project uses Emacs verilog mode to automatically generate wire definitions (although it isn't completely 
reliable right now with SystemVerilog).  If you have emacs installed, you can type 'make autos' from the
command line to update the definitions in batch mode.
