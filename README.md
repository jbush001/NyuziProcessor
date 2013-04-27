This project is a many-core General Purpose Graphics Processing Unit (GPGPU). 
Documentation is in the wiki: https://github.com/jbush001/VectorProc/wiki
Pull requests/contributions are welcome.

![rendered image](https://github.com/jbush001/VectorProc/wiki/vsim.png)

## Required Tools
I develop this primarily on Mac, but it works on Linux as well.  All of these packages should be available via
apt-get/yum if you are on the latter. 

* python 2.7
* Icarus Verilog  (http://iverilog.icarus.com/)
* GNU Make 
* gcc
* bison 
* flex 

### Optionally:
* emacs + verilog mode tools, for AUTOWIRE/AUTOINST (http://www.veripool.org/wiki/verilog-mode) (note that using 'make autos' in the rtl/ directory will run this operation in batch mode if the tools are installed)
* Java (J2SE 6+) for visualizer app 
* GTKWave (or similar) for analyzing trace files

## Building and running

### To build tools and verilog models:

  From the top directory, type 'make'
  
### Running verification tests (in verilog simulation)

    cd tests/directed_verification
    ./runtest.py
  
    cd tests/cosimulation
    ./runtest.py *.hex *.asm

### Running 3D rendering engine (in verilog simulation)

    cd firmware/3d-engine
    make vsim

Rendered framebuffer contents are saved into vsim.bmp

