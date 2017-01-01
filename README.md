# Nyuzi Processor
[![Build Status](https://travis-ci.org/jbush001/NyuziProcessor.svg?branch=master)](https://travis-ci.org/jbush001/NyuziProcessor)
[![Chat at https://gitter.im/jbush001/NyuziProcessor](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/jbush001/NyuziProcessor?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Nyuzi is an experimental multicore GPGPU processor. It supports vector floating
point, hardware multithreading, virtual memory, and cache coherence. The
SystemVerilog-based hardware implementation is synthesizable and runs on FPGA.
This project also includes an LLVM-based C++ toolchain.

**Documentation:** https://github.com/jbush001/NyuziProcessor/wiki<br/>
**Mailing list:** https://groups.google.com/forum/#!forum/nyuzi-processor-dev<br/>
**License:** Apache 2.0<br/>

# Getting Started

The following instructions explain how to set up the Nyuzi development
environment. This includes an emulator and cycle-accurate hardware simulator,
which allow hardware and software development without an FPGA.

## Install Prerequisites

### Linux (Ubuntu)

This requires Ubuntu 16 (Xenial Xeres) or later to get the proper package
versions. It should work for other distributions, but you will probably need
to change some package names. From a terminal, execute the following:

    sudo apt-get -y install autoconf cmake make gcc g++ bison flex python \
        perl emacs openjdk-8-jdk swig zlib1g-dev python-dev libxml2-dev \
        libedit-dev libncurses5-dev libsdl2-dev gtkwave imagemagick

*Emacs is used for [verilog-mode](http://www.veripool.org/wiki/verilog-mode) AUTO macros.
The makefile executes this operation in batch mode*

### MacOS

These instruction assume OSX Mavericks or later.

Open the AppStore application, search for XCode and install it. Install the
command line compiler tools by opening Terminal and typing the following:

    xcode-select --install

Install MacPorts (https://www.macports.org/install.php), and use it to install
the remaining packages:

    sudo port install cmake bison swig swig-python imagemagick libsdl2 curl emacs

You may optionally install [GTKWave](http://gtkwave.sourceforge.net/) for analyzing
waveform files.

### Windows

I have not tested this on Windows. Many of the libraries are cross platform, so
it should be possible to port it. But the easiest route is probably to run
Linux under a virtual machine like [VirtualBox](https://www.virtualbox.org/wiki/Downloads).

## Build (Linux & MacOS)

The following script will download and install the
[Nyuzi toolchain](https://github.com/jbush001/NyuziToolchain) and
[Verilator](http://www.veripool.org/wiki/verilator) Verilog simulator.
Although some Linux package managers have Verilator, they have old versions.
It will ask for your root password a few times to install stuff.

    build/setup_tools.sh

Build everything else:

    make

Run tests:

    make test

_If you are on a Linux distribution that defaults to python3, you may run into build
problems with the compiler. In tools/NyuziToolchain/tools/CMakeLists.txt, comment
out the following line:

    add_llvm_external_project(lldb)

Occasionally a change will require a new version of the compiler. To rebuild:

    git submodule update
    cd tools/NyuziToolchain/build
    make
    sudo make install

## What next?

Sample applications are available in [software/apps](software/apps). You can
run these in the emulator by typing 'make run' (some need 3rd party data
files, details are in the READMEs in those directories).

For example, this will render a 3D model in the emulator:

    cd software/apps/sceneview
    make run

# Running on FPGA

See instructions in hardware/fpga/de2-115/README.md
