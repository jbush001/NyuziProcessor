This project is a multi-core general purpose graphics processing unit (GPGPU). 
Documentation is in the wiki: https://github.com/jbush001/VectorProc/wiki.  
Pull requests/contributions are welcome.

## Required Tools

### Verilog Simulation
* Python 2.7
* Icarus Verilog  (http://iverilog.icarus.com/)
* make/gcc
* bison/flex 

### FPGA
* USB Blaster JTAG tools (https://github.com/swetland/jtag)
* libusb-1.0 (required for above)
* Quartus II FPGA design software

### Optionally:
* emacs + verilog mode tools, for AUTOWIRE/AUTOINST (http://www.veripool.org/wiki/verilog-mode) (note that using 'make autos' in the rtl/ directory will run this operation in batch mode if the tools are installed)
* Java (J2SE 6+) for visualizer app 
* GTKWave (or similar) for analyzing trace files

## Running in Verilog simulation

The development environment is fairly straightforward to get running.

### To build tools and verilog models:

From the top directory:

    make
  
### Running verification tests (in Verilog simulation)

From the top directory: 

    make test

### Running 3D rendering engine (in Verilog simulation)

    cd firmware/3d-engine
    make vsim

Rendered framebuffer contents are saved into vsim.bmp

## Running on FPGA

- Build USB blaster command line tools (https://github.com/swetland/jtag) and put into your path.  It's also necessary create etc/udev/rules.d/99-custom.rules and add the line:
ATTRS{idVendor}=="18d1" , MODE="0660" , GROUP="plugdev"

- Synthesize design using Quartus.  This will take a while.

- Load design onto board using programmer

- Run program:

    cd firmware/blinky
    ./runit.sh
   
