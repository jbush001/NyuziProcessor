This is a viewer for Wavefront .OBJ files. It can be executed in the emulator
by typing:

    make run
    
This runs the 'make_resource_py.py' script to read the OBJ file
and associated textures and write out 'resource.bin'. The MODEL_FILE 
variable in the makefile selects which OBJ file to read. The emulator
loads resource.bin as a virtual block device, which the viewer program
loads and renders. 

If the model does not contain normals, the script will generate them 
(although it will create face normals, which will potentially increase the 
number of vertices and create discontinuities where faces meet).

The Sponza model was downloaded from here:

http://graphics.cs.williams.edu/data/meshes.xml

To view other models, extract the data files to a new directory.  Change 
MODEL_FILE in the Makefile to point at the OBJ file for the new model, 
delete `resource.bin` and type `make run` again. This may require modifying 
the modelViewMatrix in viewobj.cpp to get the camera in the right position.
The first position is the position of the camera.  The second is another point in
space that the camera is looking through, and the third is a vector that points up.

	Matrix modelViewMatrix = Matrix::lookAt(Vec3(-10, 2, 0), Vec3(15, 8, 0), Vec3(0, 1, 0));

More complex models may exceed the working memory limit in librender, which may cause
an assertion:

    ASSERT FAILED: ./SliceAllocator.h:60: alignedAlloc + size < fArenaBase + fTotalSize

It can be adjusted by changing the parameter constructor to the RenderContext.

    RenderContext *context = new RenderContext(0x1000000);

There are a few debug defines in the top of sceneview.cpp:
- **TEST_TEXTURE** If defined, this will use a checkerboard texture in place of the normal textures.
  Each mip level is a different color. 
- **SHOW_DEPTH** If defined, this will shade the pixels with lighter values representing closer depth
  values and darker representing farther ones.

This program currently doesn't run on FPGA because there isn't a mass storage device to store
the data files.

