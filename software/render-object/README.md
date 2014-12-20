This is a simple 3D rendering engine.  There are currently a few hard-coded 
objects (torus, cube, and teapot) which can be selected by changing #defines 
at the top of main.cpp.  

Most of the engine is defined in software/librender. There are a few phases to the 
rendering pipeline. At the end of each phase, threads will  wait until all other 
threads are finished.  The pipeline is structured as follows:

### Geometry Phase
The vertex shader is run on sets of input vertex attributes.  It produces 
an array of output vertex parameters.  Vertices are divided between threads, each of 
which processes 16 at a time (one vertex per vector lane). There are up to 64 
vertices in progress simultaneously per core (16 vertices times four threads).  

### Triangle Setup Phase
- Backface cull triangles that are facing away from the camera
- Convert from screen space to raster coordinates. 

### Pixel Phase
Each thread works on a single 64x64 tile of the screen at a time. 

- Do a bounding box check to skip triangles that don't overlap the current tile.
- Rasterize: Recursively subdivide triangles to 4x4 squares (16 pixels). The remaining stages work on 16 pixels at a time with one pixel per vector lane.
- Z-Buffer/early reject: Interpolate the z value for each pixel, reject ones that are occluded, and update the Z-buffer.
- Parameter interpolation: Interpolated vertex parameters in a perspective correct manner for each pixel, to be passed to the pixel shader.
- Pixel shading: determine the colors for each of the pixels.
- Blend/writeback: If alpha is enabled, blend here (reject pixels where the alpha is zero). Write 
  color values into framebuffer.

The frame buffer is hard coded at location 0x200000 (2MB).

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

# To do
- Add near plane clipping.  Currently, when triangle points are at or behind the camera,
it will draw really odd things.  Need to adjust the triangle in this case, potentially 
splitting into two.
- Ability to have state changes.  Need proper command queue rather than hard coded
state in main.

