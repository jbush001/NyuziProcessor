This is a custom renderer for Quake I levels. The resource files are not checked 
in, but you can find the shareware .PAK file by searching the web. Name the file
'pak0.pak' and put into this directory. To run in simulator, type

    make run

To run on FPGA, change libos to use the ramdisk by setting the ENABLE_RAMDISK
macro in software/libs/libos/fs.c. Do a clean rebuild and type 'make fpgarun' 
to execute. It will transfer the data files over the serial port into a ramdisk 
in memory. This will take a while. The repak utility can reduce the size of the 
PAK file. Instructions are at the top of repak.cpp in this directory.

    repak -o pak0.pak <original pak location> gfx/palette.lmp maps/e1m1.bsp ...

You can load other levels by changing this line in main.cpp:

	pak.readBspFile("maps/e1m1.bsp");

At startup, this program reads the textures and packs them into a single
texture atlas. It converts each BSP leaf node into a vertex/index array so it
can render it with one draw call.

The rest of the renderer operates like the original Quake engine. A BSP walk
determines which leaf node the camera is in. The node indexes into the
potentially visible set (PVS) array. The renderer expands the run length
compressed PVS array and marks the BSP nodes that it references. It then walks
the BSP tree again, traversing surfaces from front to back. Walking in order
takes advantage of early-z rejection, skipping shading pixels that aren't
visible. As it walks the tree, it skips nodes that were not marked in the PVS.

Not implemented:
- Animated textures
- Clipping/collision detection for camera

Controls:

- Up/Down arrows: move camera forward and backwards
- Right/left arrows: rotate left and right
- U/D keys: move camera up and down
- w: toggle wireframe mode
- b: toggle bilinear filtering
- l: cycle lightmap mode: No lightmaps, Lightmaps, Lightmaps only, no texture

### Running in Verilog Simulation

In order to measure the performance of rendering one frame in simulation, you need to make
the following changes:

1. At the bottom of the main loop in main.cpp, add a call to exit(). This stop the main
loop, and will also cause the worker threads to terminate:

         		context->finish();
         		printf("rendered frame in %d instructions\n", __builtin_nyuzi_read_control_reg(6) 
         			- startInstructions);
        +		exit(1);
         	}
 	
     	return 0;

2. Increase the size of the virtual SDMMC device to fit the resource files. In rtl/testbench/sim_sdmmc.sv,
change MAX_BLOCK_DEVICE_SIZE to 'h2000000 (32 MB)

3. Increase the amount of RAM configured in the FPGA configuration. In rtl/testbench/verilator_tb.sv,
change MEM_SIZE to 'h4000000 (64 MB)

4. Type make in the rtl directory to rebuild the verilator model

Once you've made these changes, you can run the test by typing 'make verirun'.


