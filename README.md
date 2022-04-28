# Nyuzi Processor

[![CI](https://github.com/jbush001/NyuziProcessor/workflows/CI/badge.svg)](https://github.com/jbush001/NyuziProcessor/actions?query=workflow%3ACI)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/fbafdd72749e459d8de6f381abc7436d)](https://www.codacy.com/app/jbush001/NyuziProcessor?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=jbush001/NyuziProcessor&amp;utm_campaign=Badge_Grade)

Nyuzi is an experimental GPGPU processor focused on compute intensive tasks.
It includes a synthesizable hardware design written in System Verilog, an
instruction set emulator, an LLVM based C/C++ compiler, software
libraries, and tests. It can be used to experiment with microarchitectural
and instruction set design tradeoffs.

**Documentation:** <https://github.com/jbush001/NyuziProcessor/wiki><br/>

The following instructions explain how to set up the Nyuzi development
environment. This includes an emulator and cycle-accurate hardware simulator,
which allow hardware and software development without an FPGA, as well as
scripts and components to run on FPGA.

## Install Prerequisites

### Linux (Ubuntu)

This requires Ubuntu 16 (Xenial Xeres) or later to get the proper package
versions. It should work for other distributions, but you will probably need
to change some package names. From a terminal, execute the following:

    sudo apt-get -y install autoconf cmake make ninja gcc g++ bison flex python \
        python3 perl emacs openjdk-8-jdk swig zlib1g-dev python-dev \
        libxml2-dev libedit-dev libncurses5-dev libsdl2-dev gtkwave python3-pip
    pip3 install pillow

*Emacs is used for [verilog-mode](http://www.veripool.org/wiki/verilog-mode) AUTO macros.
The makefile executes this operation in batch mode*

### MacOS

These instruction assume OSX Mavericks or later.

Install XCode from the Mac AppStore ([Click Here](https://itunes.apple.com/us/app/xcode/id497799835?mt=12)).
Then install the command line compiler tools by opening Terminal and typing the
following:

    xcode-select --install

Install python libraries:

    pip3 install pillow

Install Homebrew from <https://brew.sh/>, then use it to install the remaining packages
from the terminal (do *not* use sudo):

    brew install cmake bison swig sdl2 emacs ninja

*Alternatively, you could use [MacPorts](https://www.macports.org/) if that is installed on your system, but you will need to change some of the package names*

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

    ./scripts/setup_tools.sh

Build everything else:

    cmake .
    make

Run tests:

    make tests

*If you are on a Linux distribution that defaults to python3, you may run into build
problems with the compiler. In tools/NyuziToolchain/tools/CMakeLists.txt, comment
out the following line:*

    add_llvm_external_project(lldb)

Occasionally a change will require a new version of the compiler. To rebuild:

    git submodule update
    cd tools/NyuziToolchain/build
    make
    sudo make install

## Next Steps

Sample applications are available in [software/apps](software/apps). You can
run these in the emulator by switching to the build directory and using
the run_emulator script (some need 3rd party data files, details are in
the READMEs in those directories).

For example, this will render a 3D model in the emulator:

    cd software/apps/sceneview
    ./run_emulator

To run on FPGA, see instructions in hardware/fpga/de2-115/README.md
