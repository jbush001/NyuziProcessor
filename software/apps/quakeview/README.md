This is a renderer for Quake I levels. The resource files are not checked in,
but you can find the shareware .PAK file by searching the web. Name the file
'pak0.pak' and put into this directory. To run in simulator, type

    make run

To run on FPGA, change libos to use the ramdisk by setting the ENABLE_RAMDISK
macro in fs.c. Do a clean rebuild and type 'make fpgarun' to execute. It will
transfer the data files over the serial port into a ramdisk in memory. This
will take a while.

The original GL Quake uses OpenGL 1.1 and renders each polygon individually.
This results in lots of state changes and setup overhead, and would be slow on
this architecture. Instead, I've written this custom renderer.

At startup, this program reads the textures and packs them into a single
texture atlas. It converts each BSP leaf node into a vertex/index array so it
can render it with one draw call. Quake uses repeating textures frequently. 
The pixel shader handles wrapping using texture atlas coordinates passed 
in the vertex array.

The rest of the renderer operates like the original Quake engine. A BSP walk
determines which leaf node the camera is in. The node indexes into the
potentially visible set (PVS) array. The renderer expands the run length
compressed PVS array, and marks the BSP nodes that it references. It then walks
the BSP tree again, traversing surfaces from front to back. Walking in order
takes advantage of early-z rejection, skipping shading pixels that aren't
visible. As it walks the tree, it skips nodes that were not marked in the PVS.

Controls:

- Up/Down arrows: move camera forward and backwards
- Right/left arrows: rotate left and right
- U/D keys: move camera up and down
- w: toggle wireframe mode
- b: toggle bilinear filtering
