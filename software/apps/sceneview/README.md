This is a viewer for [Wavefront .OBJ files](http://en.wikipedia.org/wiki/Wavefront_.obj_file).
It uses the 3D engine in librender. Run it in the emulator by typing:

    make run

To run on FPGA, type 'make fpgarun'. The makefile will transfer the data files
over the serial port into a ramdisk in memory. This will take a while.

The makefile invokes the 'make_resource_py.py' script. This reads the OBJ file
and associated textures and writes out 'resource.bin', which the viewer program
loads. The MODEL_FILE variable in the makefile selects which OBJ file to read.
If the model does not contain normals, the script computes them.

The Sponza model is from this repository:

http://graphics.cs.williams.edu/data/meshes.xml

To view other models, extract the data files to a new directory.  Change
MODEL_FILE in the Makefile to point at the OBJ file for the new model.
Delete `resource.bin` and type `make run` again. You may need to change the
modelViewMatrix in viewobj.cpp to put the camera in the right place.
The first parameter is the position of the camera.  The second is a point in
space that the camera is looking at. The third is a vector that points up.

    Matrix modelViewMatrix = Matrix::lookAt(Vec3(-10, 2, 0), Vec3(15, 8, 0), Vec3(0, 1, 0));

Complex models may exceed the working memory limit in librender, which
causes an assertion:

    ASSERT FAILED: ./SliceAllocator.h:60: alignedAlloc + size < fArenaBase + fTotalSize

Changing the parameter constructor to the RenderContext allocates more
memory:

    RenderContext *context = new RenderContext(0x1000000);

There are a few debug defines in the top of sceneview.cpp:
- **TEST_TEXTURE** If defined, this uses a checkerboard texture in place
of the normal textures. Each mip level is a different color.
- **SHOW_DEPTH** If defined, this shades the pixels with lighter values
representing closer depth values and darker representing farther ones.

### Running in Verilog Simulation

To measure the performance of rendering one frame in simulation, make the
following changes:

1. At the bottom of the main loop in sceneview.cpp, add a call to exit(). This stop the main
loop, and will cause the worker threads to stop:

         		context->finish();
         		printf("rendered frame in %d instructions\n", __builtin_nyuzi_read_control_reg(6)
         			- startInstructions);
        +		exit(1);
         	}

     	return 0;

2. Increase the size of the virtual SDMMC device to fit the resource files. In hardware/testbench/sim_sdmmc.sv,
change MAX_BLOCK_DEVICE_SIZE to 'h2000000 (32 MB)

3. Increase the amount of RAM configured in the FPGA configuration. In hardware/testbench/verilator_tb.sv,
change MEM_SIZE to 'h3000000 (48 MB)

4. Type make in the hardware directory to rebuild the verilator model

Once you have made these changes, you can run the test by typing 'make verirun'. This is
compute intensive and will take hours to complete. You should not run this with
VCD logging enabled, as the files will be enormous (described in hardware README).

