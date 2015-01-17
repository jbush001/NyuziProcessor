These tests validate the 3D rendering library (librender), as well as other subsystems (compiler,
emulator, etc). Each contains an image 'reference.png' that shows what the result should
look like. The result of the simulation will be written to 'output.png'. The following command
can be used to compare them.

	convert output.png reference.png -compose subtract -composite diff.png

*Unfortunately, different versions of ImageMagick produce different images for the exact
same framebuffer contents. This may be because of how the alpha channel is generated.
The raw framebuffer contents are stored in `WORK/output.bin`.*

# How to run

## Using Emulator

This is the easiest and fastest way to run the engine. From within a folder, 
type 'make run' to build and execute the project. 

It is also possible to see the output from some of these program in realtime in a 
window. To make this animate continuously (instead of stopping after rendering
one frame), modify the frame loop: 

	for (int frame = 0; frame < 1; frame++)

To run forever:

	for (int frame = 0; ; frame++)

Once you've built it, run the following command:

    ../../bin/emulator -f 640x480 WORK/program.hex

## Using Verilog model

Type 'make verirun'.  As with the emulator, the result will be written 
to output.png.

## Profiling

Type 'make profile'.  It runs the program in the verilog simulator, then 
prints a list of functions and how many instruction issue cycles occur in 
each (it does not accumulate time in a function's children).

This requires c++filt to be installed, which should be included with recent 
versions of binutils.

## Debugging

The `make debug` target launches the program in lldb. 

This is not fully functional. See notes in [here](https://github.com/jbush001/NyuziProcessor/blob/master/tools/emulator/README.md)

To obtain an assembly listing file, type `make program.lst`

### Run in single threaded mode

Is is generally easier to debug is only one hardware thread is running 
instead of the default 4. This can also rule out race conditions as a 
cause. To do this, make two changes to the sources:
- In software/libos/schedule.c, parallelExecuteAndSync, comment out this line:

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

3. Adjust the framebuffer address in main.cpp of the specific test:

```c++
Surface *colorBuffer = new (memalign(64, sizeof(Surface))) Surface(kFbWidth, kFbHeight, (void*) 0x10000000);

```

4. Adjust the base image address in Makefile of the specific test.

```make
BASE_ADDRESS=0x10140000
```

Do a clean build of the everything. 

5. Build tools/serial_boot/serial_boot
6. Load bitstream into FPGA ('make program' in rtl/fpga/de2-115/)
7. Go to software/bootloader directory and type `make run` to load serial bootloader over JTAG
8. Once this is loaded, from this directory, execute:

    ../../bin/serial_boot WORK/program.elf


