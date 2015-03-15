# Nyuzi Processor

Nyuzi is a GPGPU processor core implemented in SystemVerilog. It
features a pipelined vector floating point unit, fine grained hardware 
multithreading, multiprocessor support, and a coherent L1/L2 cache hierarchy. 
It is fully synthesizable and has been validated on FPGA. This project also 
includes a C++ toolchain based on LLVM, an emulator, software libraries, and 
RTL verification tests. It is useful as a platform for microarchitecture 
experimentation, performance modeling, and parallel software development.   

License: Apache 2.0    
Documentation: https://github.com/jbush001/NyuziProcessor/wiki  
Mailing list: https://groups.google.com/forum/#!forum/nyuzi-processor-dev  

# Running in Verilog Simulation

This environment allows cycle-accurate simulation of the hardware without an FPGA. 

## Prerequisites

The following software packages are required: 

- GCC 4.8+ or Apple Clang 4.2+
- Python 2.7
- [Verilator 3.864+](http://www.veripool.org/projects/verilator/wiki/Installing).  
- Perl 5.x+ (required by Verilator)
- C/C++ cross compiler toolchain targeting this architecture. Download and 
   build from https://github.com/jbush001/NyuziToolchain using instructions
   in the README file in that repository.
- libsdl 2.0
- ImageMagick

Optional packages:

- Emacs v23.2+, for 
   [AUTOWIRE/AUTOINST](http://www.veripool.org/projects/verilog-mode/wiki/Verilog-mode_veritedium). (This can be used in batch mode by typing 'make autos' in the rtl/ directory). 
- Java (J2SE 6+) for visualizer app 
- [GTKWave](http://gtkwave.sourceforge.net/) for analyzing waveform files 

### Linux

On Linux, these can be installed using the built-in package manager (apt-get, yum, etc). 
Here is the command line for Ubuntu:

    sudo apt-get install gcc g++ python perl emacs openjdk-7-jdk gtkwave imagemagick libsdl2-dev

On Ubuntu, you must be on 14.10 or later to get the proper version of verilator.  This requires the
[universe](https://help.ubuntu.com/community/Repositories/Ubuntu) repository to be enabled.

    sudo apt-get verilator

Bug  fixes in more recent versions of verilator are necessary for this to run correctly, so you
will need to rebuild from source if your package manager doesn't have the proper version (use verilator 
--version to check)

### MacOS

On Mavericks and later, the command line compiler can be installed by typing
`xcode-select --install`. It will also be installed automatically if you download 
XCode from the Mac App Store.

MacOS has many of these packages by default, the exceptions being Imagemagick and SDL. 
To install the remaining packages, I would recommend a package manager like 
[MacPorts](https://www.macports.org/). The command line for that would be:

    sudo port install imagemagick libsdl2
    
You will need to build verilator from source.

### Windows

I have not tested this on Windows. Many of the libraries are already cross platform, so
it should theoretically be possible.

## Building and running

1. Build verilog models, libraries, and tools. From the top directory of this 
project, type:

        make

2. To run verification tests (in Verilog simulation). From the top directory: 

        make test

3. To run 3D renderer (in emulator)

        cd software/sceneview
        make run

# Running on FPGA

This currently only works under Linux.  It uses Terasic's [DE2-115 evaluation board](http://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=502).

## Prerequisites

The following packages must be installed:

- libusb-1.0
- Brian Swetland's [USB Blaster JTAG tools](https://github.com/swetland/jtag)
- [Quartus II FPGA design software] 
   (http://www.altera.com/products/software/quartus-ii/web-edition/qts-we-index.html)
- C/C++ cross compiler toolchain described above https://github.com/jbush001/NyuziToolchain.

## Building and running

1. Build USB blaster command line tools
 * Update your PATH environment variable to point the directory where you 
   built the tools.
 * Create a file /etc/udev/rules.d/99-custom.rules and add the line (this 
   allows using USB blaster tools without having to be root)

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
    jload will automatically reset the processor as a side effect, so step 4
    does not need to be repeated each time. This test will blink the
    red LEDs on the dev board in sequence.

        cd ../../../tests/fpga/blinky
        ./runit.sh

