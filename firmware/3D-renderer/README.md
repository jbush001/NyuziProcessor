# Basic operation

This is a simple 3d rendering engine.  There are currently a few hard-coded objects.

Rendering proceeds in two basic phases.  At the end of each phase, threads will
block at a barrier until all threads are finished.
- Geometry: the vertex shader is run on sets of vertex attributes.  It produces an array 
of vertex parameters.  Vertices are divided between threads, each of which processes 16 at a time.
- Pixel: Triangles are rasterized and the vertex parameters are interpolated across
them.  The interpolated parameters are fed to the pixel shader, which returns color
values.  These values are blended and written back to the frame buffer.  Each thread
works on a single 64x64 tile of the screen at a time to ensure it is cache resident.

The frame buffer is hard coded at location 0x100000 (1MB).

# How to run

- Install prerequisites mentioned in README at top level of project.
- Note that this doesn't currently run on FPGA as is because it is larger than the internal SRAM that is addressible by the JTAG loader.  A more complex bootloader is needed. 

## Using instruction accurate simulator

This is the easiest way to run the engine and has the fewest external tool dependencies. It also executes fastest. From within this folder, type 'make run' to build and execute the project.  It will write the final contents of the framebuffer in fb.bmp.

It is also possible to see the output from the program in realtime in a Window if running on a Mac.  Once everything is built, run the following command:
<pre>
../../tools/simulator/simulator -m gui -w 512 -h 512 WORK/program.hex
</pre>

## Using Verilog model

Type 'make verirun'.  As with the instruction accurate simulator, the framebuffer will be
dumped to fb.bmp.

## Profiling

Type 'make profile'.  It runs the program in the verilog simulator, then prints a list of 
functions and how many instruciton issue cycles occur in each. It will also dump the internal processor performance counters.

This requires c++filt to be installed, which should be included with recent versions
of binutils.

## Debugging
### Finding crash locations

If a crash occurs when running in the functional simulator (using make run), you will see output like this:

    * Write Access Violation 01023231, pc 0000f490

The first number is the access address, the second is where in the code the problem occurred. 
It is possible to quickly pinpoint the instruction line with the llvm-symbolizer command.  This
is not installed in the bin directly by default, but can be invoked by using the path
where the compiler was built:

    echo 0x0000f490 | ~/src/LLVM-GPGPU/build/bin/llvm-symbolizer -obj=WORK/program.elf -functions -demangle

And it will output the function and source line:

    main
    firmware/3D-renderer/main.cpp:261:0

### Run in single threaded mode

Is is generally easier to debug is only one hardware thread is running instead of the default 4.  
This can also rule out race conditions as a cause. To do this, make two changes to the sources:
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

There is an object in Debug.h that allows printing values to the console. For example:

    Debug::debug << "This is a value: " << foo << "\n";
	
If there are multiple threads running, then the output from multiple threads will be mixed together, which is confusing.
There are two ways to remedy this:

- Print from only one thread:
	<pre>if (__builtin_vp_get_current_strand() == 0) Debug::debug &lt;&lt; "this is output\n";</pre>
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

This is not heavily tested, so mileage may vary.

    $ ../../tools/simulator/simulator -m debug WORK/program.hex 
    (dbg) 

The debugger is not symbolic and can't do much analysis, but allows inspecting memory and registers, setting breakpoints, etc.  
Type 'help' for a list of commands.

## To do
- Add near plane clipping.  Currently, when triangle points are at or behind the camera,
it will draw really odd things.  Need to adjust the triangle in this case, possibly 
splitting into two.
- Make Rasterizer clip to non-power-of-four render target sizes. Need an additional mask check.
- Ability to have state changes.  Need proper command queues rather than hard coded
state in main.
- Allocating resources in global constructors is bad.  Should clean this up.

