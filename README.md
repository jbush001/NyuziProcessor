This project is a multi-core GPGPU (general purpose graphics processing unit) core implemented in SystemVerilog. 
Documentation is available here: https://github.com/jbush001/GPGPU/wiki.  
Pull requests/contributions are welcome.

## Running in Verilog simulation

### Prerequisites
1. GCC 4.7+ or Clang 4.2+
2. Python 2.7
3. Verilator 3.862 or later (http://www.veripool.org/projects/verilator/wiki/Installing)
4. libreadline-dev (MacOS has this by default)
5. C/C++ cross compiler toolchain targeting this architecture. Download and build from https://github.com/jbush001/LLVM-GPGPU.  Instructions on how to build it are in the README file in that repository.
6. Optional: Emacs v23.2+, for AUTOWIRE/AUTOINST (Note that this doesn't require using Emacs as an editor. Using 'make autos' in the rtl/v1/ directory will run this operation in batch mode if the tools are installed).
7. Optional: Java (J2SE 6+) for visualizer app 
8. Optional: GTKWave (or similar) for analyzing waveform files (http://gtkwave.sourceforge.net/)

### Building and running

_By default, everything will use the version 1 microarchitecture located in rtl/v1. They can be made to use the v2 
microarchitecture (which is still in development) by setting the UARCH_VERSION environment variable to 'v2'_

1. Build verilog models and tools. From the top directory of this project, type:

        make

2. To run verification tests (in Verilog simulation). From the top directory: 

        make test

3. To run 3D Engine (output image stored in fb.bmp)

        cd firmware/3D-renderer
        make verirun

## Running on FPGA

### Prerequisites
This runs on Linux only.

1. USB Blaster JTAG tools (https://github.com/swetland/jtag)
2. libusb-1.0 (required for 1)
3. Quartus II FPGA design software (http://www.altera.com/products/software/quartus-ii/web-edition/qts-we-index.html)
4. Terasic's DE2-115 evaluation board.
5. C/C++ cross compiler toolchain described above

### Building and running
1. Build USB blaster command line tools (https://github.com/swetland/jtag) 
 * Update your PATH environment variable to point the directory where you built the tools.  
 * Create a file /etc/udev/rules.d/99-custom.rules and add the line: 

        ATTRS{idVendor}=="09fb" , MODE="0660" , GROUP="plugdev" 

2. Build the bitstream (ensure quartus binary directory is in your PATH, by default installed in ~/altera/13.1/quartus/bin/)

        cd rtl/v1/fpga/de2-115
        make

3. Make sure the FPGA board is in JTAG mode by setting JP3 appropriately.
4. Load the bitstream onto the board.  This is loading into configuration RAM on the FPGA.  It will be lost if the FPGA is powered off.

        make program 

5.  Load program into memory and execute it using the runit script as below.   The script assembles the source and uses the jload command to transfer the program over the USB blaster cable that was used to load the bitstream.  jload will automatically reset the processor as a side effect, so the bitstream does not need to be reloaded each time.

        cd ../../../tests/fpga/blinky
        ./runit.sh

