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
[![Chat at https://gitter.im/jbush001/NyuziProcessor](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/jbush001/NyuziProcessor?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Getting Started

This section explains how to get the design running in the cycle-accurate 
Verilog simulator and the emulator. This environment allows development of 
hardware and software without an FPGA.

### Required Software

The following sections explain how to install these packages.

- GCC 4.8+ or Apple Clang 4.2+
- Python 2.7
- [Verilator 3.864+](http://www.veripool.org/projects/verilator/wiki/Installing)  
- Perl 5.x+ (required by Verilator)
- Nyuzi cross compiler [toolchain](https://github.com/jbush001/NyuziToolchain)
- libsdl 2.0
- ImageMagick

**Optional Packages**

- Emacs v23.2+, for 
   [AUTOWIRE/AUTOINST](http://www.veripool.org/projects/verilog-mode/wiki/Verilog-mode_veritedium)
- Java (J2SE 6+) for visualizer app 
- [GTKWave](http://gtkwave.sourceforge.net/) for analyzing waveform files 

### Install Prerequisites For Linux (Ubuntu)

The following instructions are for Ubuntu version 14 or later. It should work
for other distributions with slight modifications to package names. This assumes
you have cloned this repo and have a shell open in the top directory.

Install prerequisites
	
	sudo apt-get -y install autoconf cmake gcc g++ bison flex python perl emacs curl openjdk-7-jdk zlib1g-dev swig python-dev libxml2-dev libedit-dev ncurses-dev libsdl2-dev gtkwave imagemagick 

### Install Prerequisites For MacOS

These instructions assume Mavericks or later. This assumes you have cloned this
repo and have a shell open in the top directory. If you don't have XCode
already, you can install the command line tools like this:

    xcode-select --install

Install prerequisites. This assumes MacPorts is installed (https://www.macports.org/).

    sudo port install cmake bison swig swig-python imagemagick libsdl2 curl

### Build 

Download and build Verilator (while some Linux package managers have this, it is way
out of date)

    cd tools
    curl http://www.veripool.org/ftp/verilator-3.876.tgz | tar xvz
    cd verilator-3.876/ 
	./configure 
	make
	sudo make install
	cd ../..

Download and build the Nyuzi toolchain (This clones my repo. If you want to use
your own fork, change the path below)

    git clone https://github.com/jbush001/NyuziToolchain.git tools/NyuziToolchain
    cd tools/NyuziToolchain
    mkdir build
    cd build
    cmake .. 
    make
    sudo make install
    cd ../../..
	
Build remaining tools and hardware model. Run unit tests.

    make
    make test

From here, you can try running the 3D renderer

    cd software/apps/sceneview
	 make run

### Windows

I have not tested this on Windows. Many of the libraries are already cross
platform, so it should theoretically be possible. The easiest route is probably
to run Linux under VirtualBox or VMWare.

## Running on FPGA

See instructions in hardware/fpga/de2-115/README.md

