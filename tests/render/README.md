These tests verify the 3D rendering library (librender) and other subsystems
(compiler, emulator, etc).

# How to run

## Using Emulator

From within a folder, type 'make run' to build and execute the project. It will
write the framebuffer contents to the file 'output.png'. Each directory
contains an image 'reference.png' that shows what the result should look like.

## Using Verilog model

Type 'make verirun'. As with the emulator, it writes the result image to
output.png.

## Automated test

The 'test' target will execute the tests in the emulator and automatically
check the result. Each program runs and writes the contents of its framebuffer
to a file. The test calculates the SHA-1 checksum of this output file and
compares it to a reference checksum in the Makefile.

Because of floating point rounding differences between the emulator and the
hardware model, the output may differ slightly. Therefore, the automated test
checksums are only valid for the emulator. *This should be fixed*

Unlike the other tests, this target does not generate an output.png image.

## On FPGA

Follow instructions in hardware/fpga/de2-115 to load bitstream onto FPGA
board.
1. Load bitstream into FPGA ('make program' in hardware/fpga/de2-115/)
2. Press key 0 on the lower right hand side of the board to reset it
3. From the test directory, run:

    make fpgarun

Steps 2 & 3 can be repeated

# Profiling

Type 'make profile'. It runs the program in the verilog simulator, then prints
a list of functions with how many instructions it issued in each. It does not
accumulate time in a function's children.

This requires the c++filt utility, which is part of the binutils package.

# Debugging

The `make debug` target launches the program in lldb. See notes
[here](https://github.com/jbush001/NyuziProcessor/blob/master/tools/emulator/README.md)
for more details.

To produce an assembly listing file, type `make program.lst`

## Run in single threaded mode

Is is easier to debug is only one hardware thread is running instead of the
default 4. This can also rule out race conditions as a cause. To do this,
comment out the following line in main.cpp:

    start_all_threads();
