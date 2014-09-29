# Nyuzi Processor

<img align="right" src="https://github.com/jbush001/NyuziProcessor/wiki/teapot-icon.png">

This project is a parallel processor hardware core, implemented in SystemVerilog.<br>
It is licensed under GPLv2/LGPLv2. <br>
Documentation is available here: https://github.com/jbush001/NyuziProcessor/wiki.<br>
There is a mailing list for questions or discussion here: 
https://groups.google.com/forum/#!forum/nyuzi-processor-dev

# Running in Verilog simulation

This environment allows cycle-accurate simulation of the hardware without the 
need for an FPGA. It is useful for feature implementation, debugging, and 
performance modeling.

## Prerequisites

The following software packages need to be installed. On Linux, many can be 
installed using the built-in package manager (apt-get, yum, etc). Some package
managers do have verilator, but the version is pretty old. Bug fixes in the 
most recent version are necessary for this to run correctly. MacOS should have 
libreadline-dev by default. I have not tested this under Windows.

1. GCC 4.7 or Apple Clang 4.2+
2. Python 2.7
3. Verilator 3.864 or later (http://www.veripool.org/projects/verilator/wiki/Installing).  
4. libreadline-dev
5. C/C++ cross compiler toolchain targeting this architecture. Download and 
   build from https://github.com/jbush001/NyuziToolchain.  Instructions on how 
   to build it are in the README file in that repository.
6. Optional: Emacs v23.2+, for AUTOWIRE/AUTOINST (Note that this doesn't 
   require using Emacs as an editor. Using 'make autos' in the rtl/ 
   directory will run this operation in batch mode if the tools are installed).
7. Optional: Java (J2SE 6+) for visualizer app 
8. Optional: GTKWave (or similar) for analyzing waveform files 
   (http://gtkwave.sourceforge.net/)

## Building and running

1. Build verilog models, libraries, and tools. From the top directory of this 
project, type:

        make

2. To run verification tests (in Verilog simulation). From the top directory: 

        make test

3. To run 3D Engine (output image stored in fb.bmp)

        cd firmware/3D-renderer
        make verirun

# Running on FPGA

This currently only works under Linux.  It uses Terasic's DE2-115 evaluation 
board http://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=502

## Prerequisites
The following packages must be installed:

1. libusb-1.0
2. USB Blaster JTAG tools (https://github.com/swetland/jtag)
3. Quartus II FPGA design software 
   (http://www.altera.com/products/software/quartus-ii/web-edition/qts-we-index.html)
4. C/C++ cross compiler toolchain described above https://github.com/jbush001/NyuziToolchain.

## Building and running
1. Build USB blaster command line tools
 * Update your PATH environment variable to point the directory where you built 
   the tools.  
 * Create a file /etc/udev/rules.d/99-custom.rules and add the line (this allows using 
   USB blaster tools without having to be root) 

            ATTRS{idVendor}=="09fb" , MODE="0660" , GROUP="plugdev" 

2. Build the bitstream (ensure quartus binary directory is in your PATH, by 
   default installed in ~/altera/[version]/quartus/bin/)

        cd rtl/fpga/de2-115
        make

3. Make sure the FPGA board is in JTAG mode by setting SW19 to 'RUN'
4. Load the bitstream onto the FPGA (note that this will be lost if the FPGA 
    is powered off).

        make program 

5.  Load program into memory and execute it using the runit script as below.   
    The script assembles the source and uses the jload command to transfer 
    the program over the USB blaster cable that was used to load the bitstream.  
    jload will automatically reset the processor as a side effect, so the 
    bitstream does not need to be reloaded each time. This test will blink the 
    red LEDs on the dev board in sequence.

        cd ../../../tests/fpga/blinky
        ./runit.sh

