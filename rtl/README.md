The core is an SoC component with an AXI master interface.  There are two test configurations:
- A quick and dirty FPGA testbench that simulates a simple SoC.  It includes a SDRAM controller, 
VGA controller, and an internal AXI interconnect, along with some other peripherals like a serial 
port. Most of the components for this are contained in the fpga/ directory. These are not part of 
the core proper (more information is here 
https://github.com/jbush001/GPGPU/wiki/FPGA-Implementation-Notes).  The makefile for the DE2-115 board
target is in fpga/de2-115.
- A cycle-accurate SystemVerilog simulation model built with verilator. The testbench files
are in the testbench/ directory. It will generate an exeutable 'verilator_model' in the bin/ directory
at the top level.

The Verilog simulation model accepts the following arguments (Verilog arguments begin with a plus sign):

|Argument|Value|
|--------|-----|
| +bin=&lt;hexfile&gt; | File to be loaded to simulator memory at boot. Each line contains a 32-bit hex encoded value |
| +regtrace=1 | Enables dumping of register and memory transfers to standard out.  This is used during cosimulation |
| +statetrace=1 | Enable thread state tracing, used for visualizer app (see tools/visualizer)
| +memdumpfile=&lt;filename&gt; | Dump simulator memory to a binary file at the end of simulation. The next two parameters must also be specified for this to work |
| +memdumpbase=&lt;baseaddress&gt;| Base address in simulator memory to start dumping |
| +memdumplen=&lt;length&gt; | Number of bytes of memory to dump |
| +autoflushl2=1 | If specified, will automatically copy any dirty data in the L2 to system memory before dumping |

A few coding/design conventions are generally observed:

* There is single clock domain, always posedge triggered. No multicycle paths are used.
* There is a global 'reset' that is asynchronous and active high.
* SRAMs are instantiated using generic modules sram_1r1w/sram_2r1w.
* One file is used per module and the name of the module is the same as the name of the file.
* Instance names are generally the same as the module that is being instantiated, potentially with a descriptive
 suffix.
* The order of code in the module attempts to reflect the order from input to output, top to bottom.
* For non-generic modules, signal names are maintained throughout the hierarchy (ie they are not 
renamed via port mappings).
* Each pipeline stage is generally in a single module. Inputs are unregistered, outputs are 
registered.
* Module ports are grouped by the source/destination module in pipeline stages, or sometimes by 
related function in other module types, with a comment identifying such above each group.
* Identifiers use a common set of suffixes:

|Suffix|Meaning |
|------|--------|
| _en  | Use for a signal that enables some operation. Internal enables are always active high. |
| _oh  | One-hot. No more than one signal will be set, indicating an index |
| _idx | Signal is an index. Usually used when one-hot signals of the same name are also present |
| _t   | Typedef |
| _gen | Generated block |
| _nxt | Combinational logic that generates the next value (input) for a flop.  Used to distinguish the input from the output of the flop |

* Signals that connect pipeline stages have a abbreviated prefix referring to the source stage (for example, ts_XXX comes from thread select stage) 
* In any place where a configurable parameter, constant, or typedef is used in more than one module, it is declared in defines.v (which is included in all files) rather than a module parameter which needs to be daisy chained around.

