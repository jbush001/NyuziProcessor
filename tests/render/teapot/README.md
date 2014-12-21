This renders a teapot

# How to run

## Using Emulator

This is the easiest and fastest way to run the engine. From within this folder, 
type 'make run' to build and execute the project.  It will write the final 
contents of the framebuffer in framebuffer.png.

It is also possible to see the output from the program in realtime in a 
window. To make this animate continuously (instead of stopping after rendering
one frame), modify the frame loop: 

	for (int frame = 0; frame < 1; frame++)

To run forever:

	for (int frame = 0; ; frame++)

Once you've built it, run the following command:

    ../../bin/emulator -f 640x480 WORK/program.hex

## Using Verilog model

Type 'make verirun'.  As with the emulator, the framebuffer will be written 
to framebuffer.png.

## Profiling

Type 'make profile'.  It runs the program in the verilog simulator, then 
prints a list of functions and how many instruction issue cycles occur in 
each (it does not accumulate time in a function's children).

This requires c++filt to be installed, which should be included with recent 
versions of binutils.

## Debugging

See notes in https://github.com/jbush001/NyuziProcessor/blob/master/tools/emulator/README.md

### Run in single threaded mode

Is is generally easier to debug is only one hardware thread is running 
instead of the default 4. This can also rule out race conditions as a 
cause. To do this, make two changes to the sources:
- In software/os/schedule.c, parallelExecuteAndSycn, comment out this line:

    __builtin_nyuzi_write_control_reg(30, 0xffffffff);	// Start all threads

## Running on FPGA
The FPGA board (DE2-115) must be connected both with the USB blaster cable and 
a serial cable. The serial boot utility is hardcoded to expect the serial device 
to be in /dev/cu.usbserial. The following changes must be made manually to handle
the different memory layout of the FPGA environment

1. In software/libc/src/sbrk.c, adjust the base heap address:

```c++
volatile unsigned int gNextAlloc = 0x10340000;	
```

2. In software/libc/os/crt0.s, adjust the stack address.  

```asm
stacks_base:		.long 0x10340000
```

3. Adjust the framebuffer address in software/render-object/main.cpp:

```c++
render::Surface gColorBuffer(0x10000000, kFbWidth, kFbHeight);
```

4. Adjust the base image address in software/render-object/Makefile.  Do a clean build of render-object.

```make
BASE_ADDRESS=0x10140000
```

Do a clean build of the everything. 

5. Build tools/serial_boot/serial_boot
6. Load bitstream into FPGA ('make program' in rtl/fpga/de2-115/)
7. Go to software/bootloader directory and type `make run` to load serial bootloader over JTAG
8. Once this is loaded, from this directory, execute:

    ../../bin/serial_boot WORK/program.elf


