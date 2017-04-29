This is a custom renderer for Quake I levels. The resource files are not
checked in, but you can find the shareware .PAK file by searching the web. Name
the file 'pak0.pak' and put into this directory.

Not implemented:
- Animated textures
- Clipping/collision detection for camera

Controls:
- Up/Down arrows: move camera forward and backward
- Right/left arrows: rotate left and right
- U/D keys: move camera up and down
- w: toggle wireframe mode
- b: toggle bilinear filtering
- l: cycle lightmap mode: Texture only, lightmaps + texture, lightmaps only

You can load other episodes/missions by changing this line in main.cpp:

	pak.readBspFile("maps/e1m1.bsp");

## Running in Emulator

To run in emulator, type:

    make run

The default screen resolution is 640x480. To change this, update the variables
FB_WIDTH and FB_HEIGHT in the Makefile.

## Running on FPGA

To run on FPGA, type 'make fpgarun'. It will transfer the data files over the
serial port into a ramdisk in memory. This will take a while. The repak utility
(tools/repak) can reduce the size of the PAK file. Move the original PAK file
in a different directory, then:

    ../../../bin/repak -o pak0.pak <original pak location> gfx/palette.lmp maps/e1m1.bsp

If you want to load a different mission, it to the end of the repak command line (for example,
maps/e1m2.bsp). You can list all files in the PAK file like this:

    ../../../bin/repak -l pak0.pak

## Running in Verilog Simulation

To measure the performance of rendering one frame in simulation, you need to
make the following changes:

1. At the bottom of the main loop in main.cpp, add a call to exit(). This exits the main
loop and stops the worker threads:

             context->finish();
             printf("rendered frame in %d uS\n", clock() - time);
        +		exit(1);
         	}

     	return 0;

2. Comment out keyboard polling in main. In the verilator configuration, there is a dummy module that
generates continuous keypresses, but this will cause an infinite loop with this program:

            for (int frame = 0; ; frame++)
            {
        -       processKeyboardEvents();
        +//     processKeyboardEvents();


3. Increase the size of the virtual SDMMC device to fit the resource files. In hardware/testbench/sim_sdmmc.sv,
change MAX_BLOCK_DEVICE_SIZE to 'h2000000 (32 MB)

4. Increase the amount of RAM configured in the FPGA configuration. In hardware/testbench/verilator_tb.sv,
change MEM_SIZE to 'h4000000 (64 MB)

5. Type make in the hardware directory to rebuild the verilator model

Once you have made these changes, run the test by typing 'make verirun'.

## Implementation

At startup, this program reads the textures and packs them into a single
texture atlas. It converts each BSP leaf node into a vertex/index array so it
can render it with one draw call.

The rest of the renderer operates like the original Quake engine. A BSP walk
determines which leaf node the camera is in. The node indexes into the
potentially visible set (PVS) array. The renderer expands the run length
compressed PVS array and marks the BSP nodes that it references. It then walks
the BSP tree again, traversing surfaces from front to back. Walking in order
takes advantage of early-z rejection, skipping shading pixels that aren't
visible. As it walks the tree, it skips nodes that that the PVS did not mark.

Lightmaps are similarily assembled into a texture map and applied in the pixel
shader.
