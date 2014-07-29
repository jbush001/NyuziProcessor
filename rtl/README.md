There are two separate implementations here:
 * v1/ is pretty much functionally complete, running in Verilog simulaton or FPGA
 * v2/ is a complete redesign of the core that attempts to improve performance, but is still a work in progress. It runs in Verilog simulation, but not on FPGA.

Each core is essentially an SoC component, with an AXI master interface.  There is a quick and dirty FPGA testbench that simulates a simple SoC for testing.  It includes a SDRAM controller, VGA controller, and an internal AXI interconnect, along with some other peripherals like a serial port. Most of the components for this are contained in the fpga_common/ directory.  This is test code and not part of the core proper (more information is here https://github.com/jbush001/GPGPU/wiki/V1-FPGA-Implementation-Notes)

Within each version, there are a few key files:
 * Makefile: used to build the Verilator simulator modules
 * fpga/: Top level FPGA module that is specific to this core (it references modules from fpga_common/)
 * fpga/de2-115: Files specific to the FPGA family, including a synthesis makefile.
 * core/: The GPGPU component itself
 * testbench/: Includes the top level verilog file, Verilator sundries, and various mock simulator modules like SDRAM or JTAG.

Being aware of a few (very) loose coding/design conventions that are observed might help understanding this code.
* A single clock domain is used within the core, always posedge triggered. No multicycle paths are used.
* The global signal 'reset' is used within the core.  It is asynchronous and active high.
* SRAMs use generic modules sram_1r1w/sram_2r1w rather than being instantiated directly with logic arrays.
* One file is used per module and the name of the module is the same as the name of the file.
* Instance names are generally the same as the module that is being instantiated, potentially with a descriptive
 suffix.

Generally modules can be one of two types: a generic library component (like arbiter or sram_1r1w), or a non-generic component like l1_miss_queue. The following conventions are used for the latter:

* Each pipeline stage is generally in a single module. Inputs are unregistered, fed into combinational logic, which is then registered on the output side. The order of code in the module tries to reflect the order from input to output, with combinational logic defined at the top of the file (dependent signals being defined before the logic that uses them) and flip flops near the bottom.
* Signal names are maintained throughout the hierarchy (ie they are not renamed via port mappings)
* Module ports are grouped by the source/destination module, with a comment identifying such above each group.
* Identifiers use a common set of suffixes:

|Suffix|Meaning |
|----|----|
| _en  | Use for a signal that enables some operation. Internal enables are always active high. |
| _oh  | One-hot. No more than one signal will be set, indicating an index |
| _idx | Signal is an index. Usually used when one-hot signals of the same name are also present |
| _t   | Typedef |
| _gen | Generated block |

* Signals that connect pipeline stages have a abbreviated prefix referring to the source stage (for example, id_XXX comes from instruction decode stage) 
* In any place where a configurable parameter, constant, or typedef is used in more than one non-generic module, it is declared in defines.v (which is included in all files) rather than a module parameter which needs to be daisy chained around.

