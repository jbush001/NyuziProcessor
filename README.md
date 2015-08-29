# Nyuzi Processor

Nyuzi is an experimental multicore GPGPU processor. It supports vector floating
point, hardware multithreading, and cache coherence. The SystemVerilog-based 
hardware implementation is synthesizable and runs on FPGA. This project also 
includes an LLVM-based C++ toolchain, a symbolic debugger, an emulator, software 
libraries, and hardware verification tests. It is useful for microarchitecture 
experimentation, performance modeling, and parallel software development.

**Documentation:** https://github.com/jbush001/NyuziProcessor/wiki  
**Mailing list:** https://groups.google.com/forum/#!forum/nyuzi-processor-dev   
**License:** Apache 2.0    
**Blog:** http://latchup.blogspot.com/   
**Chat:** [![Chat at https://gitter.im/jbush001/NyuziProcessor](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/jbush001/NyuziProcessor?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Getting Started

This section explains how to get the design running in the cycle-accurate 
Verilog simulator and the emulator. This environment allows development of 
hardware and software without an FPGA.

### Required Software

The following sections explain how to install these packages for each operating
system.

- GCC 4.8+ or Apple Clang 4.2+
- Python 2.7
- [Verilator 3.864+](http://www.veripool.org/projects/verilator/wiki/Installing)  
- Perl 5.x+ (required by Verilator)
- Nyuzi cross compiler toolchain: https://github.com/jbush001/NyuziToolchain 
- libsdl 2.0
- ImageMagick

### Optional Software:

- Emacs v23.2+, for 
   [AUTOWIRE/AUTOINST](http://www.veripool.org/projects/verilog-mode/wiki/Verilog-mode_veritedium)
- Java (J2SE 6+) for visualizer app 
- [GTKWave](http://gtkwave.sourceforge.net/) for analyzing waveform files 

### Building on Linux

Build the Nyuzi toolchain following instructions in https://github.com/jbush001/NyuziToolchain 

Next, you will need Verilator. Although many package managers have Verilator, 
it is usually out of date. Bug fixes in at least version 3.864 are necessary 
for it to run properly. Some of the bugs are subtle, so it may appear to work 
at first but then fail in odd ways if you are out of date. Build from source 
using these instructions:

http://www.veripool.org/projects/verilator/wiki/Installing

You can install the remaining dependencies using the package manager (apt-get, 
yum, etc). The instructions below are for Ubuntu. You may need to change the 
package names for other distributions:

    sudo apt-get install gcc g++ python perl emacs openjdk-7-jdk gtkwave imagemagick libsdl2-dev

    git clone https://github.com/jbush001/NyuziProcessor.git
    cd NyuziProcessor
    make
    make test
    
To run 3D renderer (in emulator)

    cd software/apps/sceneview
    make run
    
### Building on MacOS

Build the Nyuzi toolchain following instructions in
https://github.com/jbush001/NyuziToolchain. The host compiler is also
installed, if not already present, as part of that process.

Build Verilator from source using instructions here:

http://www.veripool.org/projects/verilator/wiki/Installing

MacOS has many of the required packages by default. To install the remaining
packages, I would recommend a package manager like [MacPorts](https://www.macports.org/). 
The following commands will set up the project using that:

    sudo port install imagemagick libsdl2

    git clone https://github.com/jbush001/NyuziProcessor.git
    cd NyuziProcessor
    make
    make test

To run 3D renderer (in emulator)

    cd software/sceneview
    make run

### Building on Windows

I have not tested this on Windows. Many of the libraries are already cross
platform, so it should theoretically be possible. The easiest route is probably
to run Linux under VirtualBox or VMWare.

## Running on FPGA

See instructions in hardware/fpga/de2-115/README.md

