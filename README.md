This project is a multi-core general purpose graphics processing unit (GPGPU). 
Documentation is available here: https://github.com/jbush001/GPGPU/wiki.  
Pull requests/contributions are welcome.

## Required Tools
* Host toolchain (GCC, etc.)
* C/C++ cross compiler toolchain (https://github.com/jbush001/LLVM-GPGPU)
* Python 2.7
* Verilator 3.851 (http://www.veripool.org/projects/verilator/wiki/Installing)

### FPGA
* USB Blaster JTAG tools (https://github.com/swetland/jtag)
* libusb-1.0 (required for above)
* Quartus II FPGA design software

### Optional:
* Emacs + verilog mode tools, for AUTOWIRE/AUTOINST http://www.veripool.org/wiki/verilog-mode. (Note that this doesn't require using Emacs as an editor. Using 'make autos' in the rtl/ directory will run this operation in batch mode if the tools are installed).
* Java (J2SE 6+) for visualizer app 
* GTKWave (or similar) for analyzing waveform files

## Running in Verilog simulation

The development environment should be relativey easy to set up.

### To build tools and verilog models:

First, you must download and build the LLVM toolchain from here: https://github.com/jbush001/LLVM-GPGPU.  The README file in the root directory provides instructions.

Once this is done, from the top directory of this project:

    make
  
### Running verification tests (in Verilog simulation)

From the top directory: 

    make test

## Running on FPGA
This runs on Terasic's DE2-115 evaluation board. These instructions are for Linux only.

- Build USB blaster command line tools (https://github.com/swetland/jtag) 
 * Update your PATH environment variable to point the directory where you built the tools.  
 * Create a file /etc/udev/rules.d/99-custom.rules and add the line: ATTRS{idVendor}=="09fb" , MODE="0660" , GROUP="plugdev" 
- Open the project file in rtl/fpga/de2-115/fpga-project.qpf in Quartus and synthesize it.  This will take a while.
- Load configuration bitstream into FPGA using the Quartus programmer.
- Load program into memory and execute it using the runit script as below. The script assembles the source and uses the jload command to transfer the program over the USB blaster cable that was used to load the bitstream.
<pre>
cd tests/fpga/blinky
./runit.sh
</pre>

