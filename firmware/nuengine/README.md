# Basic operation

This is a simple 3d rendering engine.  There are currently a few hard-coded objects.

Rendering proceeds in two basic phases.  At the end of each phase, threads will
block at a barrier until all threads are finished.
- Geometry: the vertex shader is run on sets of vertex attributes.  It produces an array 
of vertex parameters.
- Pixel: Triangles are rasterized and the vertex parameters are interpolated across
them.  The interpolated parameters are fed to the pixel shader, which returns color
values.  These values are blended and written back to the frame buffer.  Each thread
works on a single 64x64 tile of the screen at a time to ensure it is cache resident.

The frame buffer is hard coded at location 0x100000 (1MB).

# How to run

## Using instruction accurate simulator

This is the easiest way to run the engine and has the fewest external tool dependencies. It also
executes fastest.
- The C++ compiler for this target must be built and installed (https://github.com/jbush001/LLVM-GPGPU)
- Need to build local tools by typing 'make' in the top directory of this project.

From within this folder, type 'make run' to build and execute the project.  It will
write the final contents of the framebuffer in fb.bmp.

## Using verilog model

This requires having the Verilog model built.  
- Make sure Verilator is installed (http://www.veripool.org/projects/verilator/wiki/Installing)
- cd into the rtl/ directory and type 'make verilator'

Type 'make verirun'.  As in the instruction accurate simulator, the framebuffer will be
dumped to fb.bmp.

## Profiling

Same as above, except use 'make profile'.  It will run for a while, then print a list 
of functions and how many cycles are spent in each. It will also dump the internal 
processor performance counters.

This requires c++filt to be installed, which should be included with recent versions
of binutils.

## Debugging

There is an object in Debug.h that allows printing values to the console. For example:

    Debug::debug << "This is a value: " << foo << "\n";

Another way of debugging is to enable verbose instruction logging.  In the Makefile, 
under the run target, add -v to the parameters for the ISS command. Type 'make run'. 
This will dump every memory and register transfer to the console.  When the project 
is built, and assembly listing is printed into program.lst.  These can be compared 
to understand how the program is operating.

## To do
- Add near plane clipping.  Currently, when triangle points are at or behind the camera,
it will draw really odd things.  Need to adjust the triangle in this case, possibly 
splitting into two.
- Make Rasterizer clip to non-power-of-four render target sizes.
- Ability to have state changes.  Need proper command queues rather than hard coded
state in main.
- Allocating resources in global constructors is bad.  Should clean this up.

