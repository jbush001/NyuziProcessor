# Nyuzi Processor

Nyuzi is an experimental GPGPU processor implemented in SystemVerilog. It
supports vector floating point, fine grained hardware multithreading, 
multiprocessing, and a coherent L1/L2 cache hierarchy. It is fully 
synthesizable and has been validated on FPGA. This project also includes 
a C++ toolchain based on LLVM, an emulator, software libraries, and RTL 
verification tests. It is useful as a platform for microarchitecture 
experimentation, performance modeling, and parallel software development.   

License: Apache 2.0    
Documentation: https://github.com/jbush001/NyuziProcessor/wiki  
Mailing list: https://groups.google.com/forum/#!forum/nyuzi-processor-dev  
Blog: http://latchup.blogspot.com/

# Getting Started

These instructions explain how to get the design working in Verilog simulation.
This environment allows cycle-accurate modeling of the hardware without an FPGA. 

## Required Software

Instructions for obtaining these packages are in the following sections.

- GCC 4.8+ or Apple Clang 4.2+
- Python 2.7
- [Verilator 3.864+](http://www.veripool.org/projects/verilator/wiki/Installing).  
- Perl 5.x+ (required by Verilator)
- Nyuzi cross compiler toolchain: https://github.com/jbush001/NyuziToolchain 
- libsdl 2.0
- ImageMagick

## Optional Software:

- Emacs v23.2+, for 
   [AUTOWIRE/AUTOINST](http://www.veripool.org/projects/verilog-mode/wiki/Verilog-mode_veritedium).
- Java (J2SE 6+) for visualizer app 
- [GTKWave](http://gtkwave.sourceforge.net/) for analyzing waveform files 

## Building on Linux

First, build the Nyuzi toolchain following instructions in https://github.com/jbush001/NyuziToolchain 

Next, you will need Verilator.  Many package managers have Verilator, but it 
may be old. If you don't have it already, try to install it as follows:

    sudo apt-get install verilator
    verilator --version.

Bug fixes in at least version 3.864 are necessary for it to run properly 
(some of the bugs are subtle, so it may appear to work at first but then 
fail in odd ways if you are out of date). If you don't have a recent 
version, build from source using these instructions:

http://www.veripool.org/projects/verilator/wiki/Installing

On Linux, the remaining dependencies can be installed using the built-in 
package manager (apt-get, yum, etc). I've only tested this on Ubuntu, for 
which the instructions are below. You may need to tweak the package names 
for other distros:

    sudo apt-get install gcc g++ python perl emacs openjdk-7-jdk gtkwave imagemagick libsdl2-dev

    git clone git@github.com:jbush001/NyuziProcessor.git
    cd NyuziProcessor
    make
    make test
    
To run 3D renderer (in emulator)

    cd software/sceneview
    make run
    

## Building on MacOS

On Mavericks and later, the command line compiler can be installed by typing

    xcode-select --install 
    
It will also be installed automatically if you download XCode from the Mac App Store.

Build the Nyuzi toolchain following instructions in https://github.com/jbush001/NyuziToolchain 

You will need to build verilator from source using instructions here:

http://www.veripool.org/projects/verilator/wiki/Installing

MacOS has many of the required packages by default, the exceptions being
Imagemagick and SDL. To install the remaining packages, I would recommend
a package manager like [MacPorts](https://www.macports.org/). The command
line for that would be:

    sudo port install imagemagick libsdl2

    git clone git@github.com:jbush001/NyuziProcessor.git
    cd NyuziProcessor
    make
    make test

To run 3D renderer (in emulator)

    cd software/sceneview
    make run

## Building on Windows

I have not tested this on Windows. Many of the libraries are already cross platform, so
it should theoretically be possible.

# Running on FPGA

This currently only works under Linux.  It uses Terasic's [DE2-115 evaluation board](http://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=502).

## Required Software

In addition to the packages listed above, this requires:

- libusb-1.0
- Brian Swetland's [USB Blaster JTAG tools](https://github.com/swetland/jtag)
- [Quartus II FPGA design software] 
   (http://www.altera.com/products/software/quartus-ii/web-edition/qts-we-index.html)

## Building and Running

1. Build USB blaster command line tools 
     
        sudo apt-get install libusb-dev
        git clone https://github.com/swetland/jtag
        cd jtag
        make 

    Once this is built:
     * Update your PATH environment variable to point the directory where you 
       built the tools (there is no install target for this project).
     * Create a file /etc/udev/rules.d/99-custom.rules and add the following line (this 
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

