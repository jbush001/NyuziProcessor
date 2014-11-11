# Basic operation

This is a simple 3d rendering engine.  There are currently a few hard-coded 
objects (torus, cube, and teapot) which can be selected by changing #defines 
at the top of main.cpp.

There are a few phases to the rendering pipeline. At the end of each phase, threads will 
block at a barrier until all other threads are finished.  The pipeline is structured
as follows:

### Geometry Phase

- Vertex Sharing: The vertex shader is run on sets of input vertex attributes.  It produces 
an array of output vertex parameters.  Vertices are divided between threads, each of 
which processes 16 at a time (one vertex per vector lane). There are up to 64 
vertices in progress simultaneously per core (16 vertices times four threads).  

### Setup Phase
- Triangle setup & culling: Skip triangles that are facing away from the camera (backface culling).  Do a simple bounding box check to skip triangles that don't overlap the current tile.  Convert from screen space to raster coordinates. 

### Pixel Phase
Each thread works on a single 64x64 tile of the screen at a time. 

- Rasterization: Recursively subdivide triangles to 4x4 squares (16 pixels). The remaining stages work on 16 pixels at a time with one pixel per vector lane.
- Z-Buffer/early reject: Interpolate the z value for each pixel, reject ones that are not visible, and update the Z-buffer.
- Parameter interpolation: Interpolated vertex parameters in a perspective correct manner for each pixel, to be passed to the pixel shader.
- Pixel shading: determine the colors for each of the pixels.
- Blend/writeback: If alpha is enabled, blend here (reject pixels where the alpha is zero). Write values into framebuffer.

The frame buffer is hard coded at location 0x200000 (2MB).

# How to run

- Install prerequisites mentioned in README at top level of project.

## Using instruction accurate simulator

This is the easiest way to run the engine and has the fewest external tool 
dependencies. It also executes fastest. From within this folder, type 
'make run' to build and execute the project.  It will write the final 
contents of the framebuffer in fb.bmp.

It is also possible to see the output from the program in realtime in a 
window if running on a Mac.  Once you've built it, run the following 
command:
<pre>
../../bin/simulator -m gui -w 640 -h 480 WORK/program.hex
</pre>

## Using Verilog model

Type 'make verirun'.  As with the instruction accurate simulator, the 
framebuffer will be dumped to fb.bmp.

## Profiling

Type 'make profile'.  It runs the program in the verilog simulator, then 
prints a list of functions and how many instruciton issue cycles occur in 
each. It will also dump the internal processor performance counters.

This requires c++filt to be installed, which should be included with recent 
versions of binutils.

## Debugging
### Mapping program addresses to line numbers

It is possible to pinpoint the instruction line with the llvm-symbolizer command.  This is not installed in the bin directly by default, but can be invoked by using the path where the compiler was built, for example:

    echo 0x00011d80 | ~/src/NyuziToolchain/build/bin/llvm-symbolizer -obj=WORK/program.elf -demangle

And it will output the function and source line:

    render::Rasterizer::fillTriangle(render::PixelShader*, int, int, int, int, int, int, int, int)
    NyuziProcessor/software/3D-renderer/Rasterizer.cpp:223:0

### Run in single threaded mode

Is is generally easier to debug is only one hardware thread is running 
instead of the default 4. This can also rule out race conditions as a 
cause. To do this, make two changes to the sources:
- In start.s, change the strand enable mask from 0xffffffff to 1:

    ; Set the strand enable mask to the other threads will start.
    move s0, 0xffffffff
    setcr s0, 30

Becomes:

    ; Set the strand enable mask to the other threads will start.
    move s0, 1
    setcr s0, 30
    
- In Core.h, change kHardwareThreadPerCore from 4 to 1:
<pre>
const int kHardwareThreadsPerCore = 1;
</pre>

### Console debugging

There is an object in Debug.h that allows printing values to the console. 
For example:

    Debug::debug << "This is a value: " << foo << "\n";
	
If there are multiple threads running, then the output from multiple threads 
will be mixed together, which is confusing. There are two ways to remedy this:

- Print from only one thread:
	<pre>if (__builtin_nyuzi_get_current_strand() == 0) Debug::debug &lt;&lt; "this is output\n";</pre>
- Run in single threaded mode as described above

### Tracing

Another way of debugging is to enable verbose instruction logging.  In the Makefile, 
under the run target, add -v to the parameters for the SIMULATOR command. 

    $(SIMULATOR) -v -d $(WORKDIR)/fb.bin,100000,12C000 $(WORKDIR)/program.hex

Type 'make run'. 
This will dump every memory and register transfer to the console.  When the project 
is built, and assembly listing is printed into program.lst.  These can be compared 
to understand how the program is operating.

    0000f43c [st 0] s0 &lt;= 00010000
    0000f428 [st 1] s0 &lt;= 00000001
    0000f414 [st 2] writeMemWord 000f7a74 00000000
    0000f400 [st 3] s0 &lt;= 3e8a867a
    0000f440 [st 0] s30 &lt;= 0000f444

These can then be compared directly to program.lst:

    f428:	00 04 80 07                                  	move s0, 1
    f42c:	1d 20 14 82                                  	store_8 s0, 1288(sp)
    f430:	60 03 00 ac                                  	getcr s27, 0
    f434:	5b 03 80 08                                  	setne_i s26, s27, 0
    f438:	1a 02 00 f4                                  	btrue s26, main+772
    f43c:	1f b0 ef a9                                  	load_32 s0, -1044(pc)

### Debugger

    $ ../../tools/simulator/simulator -m debug WORK/program.hex 
    (dbg) 

The debugger is not symbolic and can't do much analysis, but allows inspecting 
memory and registers, setting breakpoints, etc. Type 'help' for a list of commands.

## Running on FPGA
The FPGA board (DE2-115) must be connected both with the USB blaster cable and 
a serial cable. The serial boot utility is hardcoded to expect the serial device 
to be in /dev/cu.usbserial.

1. Apply fpga.patch to the 3D engine to adjust memory layout of program (patch &lt; fpga.patch). Do a clean rebuild. 
2. Build tools/serial_boot/serial_boot
2. Load bitstream into FPGA ('make program' in rtl/fpga/de2-115/)
3. Go to software/bootloader directory and type `make run` to load serial bootloader over JTAG
4. Once this is loaded, from this directory, execute:

    ../../bin/serial_boot WORK/program.elf

# To do
- Add near plane clipping.  Currently, when triangle points are at or behind the camera,
it will draw really odd things.  Need to adjust the triangle in this case, potentially 
splitting into two.
- Ability to have state changes.  Need proper command queues rather than hard coded
state in main.
- Allocating resources in global constructors is bad.  Should clean this up.

