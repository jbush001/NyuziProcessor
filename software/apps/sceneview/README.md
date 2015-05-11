This is a viewer for [Wavefront .OBJ files](http://en.wikipedia.org/wiki/Wavefront_.obj_file). 
The emulator will run it if you type:

    make run

The makefile invokes the 'make_resource_py.py' script. This reads the OBJ file 
and associated textures and write out 'resource.bin'. The MODEL_FILE variable 
in the makefile selects which OBJ file to read. The viewer program loads this 
and renders it. 

If the model does not contain normals, the script will generate them.

The Sponza model is from this repository:

http://graphics.cs.williams.edu/data/meshes.xml

To view other models, extract the data files to a new directory.  Change 
MODEL_FILE in the Makefile to point at the OBJ file for the new model. 
Delete `resource.bin` and type `make run` again. You may need to change the 
modelViewMatrix in viewobj.cpp to put the camera in the right place.
The first parameter is the position of the camera.  The second is a point in
space that the camera is looking at. The third is a vector that points up.

    Matrix modelViewMatrix = Matrix::lookAt(Vec3(-10, 2, 0), Vec3(15, 8, 0), Vec3(0, 1, 0));

Complex models may exceed the working memory limit in librender, which will 
cause an assertion:

    ASSERT FAILED: ./SliceAllocator.h:60: alignedAlloc + size < fArenaBase + fTotalSize

Changing the parameter constructor to the RenderContext will allocate more 
memory:

    RenderContext *context = new RenderContext(0x1000000);

There are a few debug defines in the top of sceneview.cpp:
- **TEST_TEXTURE** If defined, this will use a checkerboard texture in place 
of the normal textures. Each mip level is a different color. 
- **SHOW_DEPTH** If defined, this will shade the pixels with lighter values 
representing closer depth values and darker representing farther ones.

This program doesn't run on FPGA yet because there isn't a mass storage device 
to store the data files.