These tests verify the 3D rendering library (librender), as well as other 
subsystems (compiler, emulator, etc). Each contains an image 'reference.png' 
that shows what the result should look like. Tests write the result of the 
simulation to 'output.png'. The following command compares them.

    convert output.png reference.png -compose subtract -composite diff.png

*Unfortunately, different versions of ImageMagick produce different images 
for the exactsame framebuffer contents. This may be because of how the renderer 
outputs the alpha channel.*

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

    ../../../bin/emulator -f 640x480 WORK/program.hex

## Using Verilog model

Type 'make verirun'.  As with the emulator, it writes the result image
to output.png.

## On FPGA

1. Load bitstream into FPGA ('make program' in rtl/fpga/de2-115/)
2. Press key 0 on the lower right hand side of the board to reset it
3. From the test directory, run:

    make fpgarun
    
Steps 2 & 3 can be repeated

# Profiling

Type 'make profile'.  It runs the program in the verilog simulator, then 
prints a list of functions with how many instruction issue cycles occured in 
each. It does not accumulate time in a function's children.

This requires c++filt to be installed, which should be included with recent 
versions of binutils.

# Debugging

The `make debug` target launches the program in lldb. 

This is not fully functional. See notes in [here](https://github.com/jbush001/NyuziProcessor/blob/master/tools/emulator/README.md)

To obtain an assembly listing file, type `make program.lst`

## Run in single threaded mode

Is is generally easier to debug is only one hardware thread is running 
instead of the default 4. This can also rule out race conditions as a 
cause. To do this, make two changes to the sources:
- In main, comment out this line:

    __builtin_nyuzi_write_control_reg(30, 0xffffffff);    // Start all threads

