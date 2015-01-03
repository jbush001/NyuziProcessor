This is a viewer for Wavefront .OBJ files. It can be executed in the emulator
by typing:

    make run
    
This executes the 'make_resource_py.py' script to read the OBJ file
and associated textures and write out 'resource.bin'. The MODEL_FILE 
variable in the makefile selects which OBJ file to read. The emulator
loads resource.bin as a virtual block device, which the viewer reads 
and renders. 

If the model does not contain normals, the script will generate them 
(although it will create face normals, which will potentially increase the 
number of vertices and create discontinuities where faces meet).

To view other models, delete 'resource.bin, change MODEL_FILE to point 
at the OBJ file for the new model and type `make run` again. This will
probably require tweaking the modelViewMatrix in viewobj.cpp to 
get the camera in the right position.  There is code to perform an initial
translation and rotation in main:

	Matrix modelViewMatrix = Matrix::getTranslationMatrix(0.0, -2.0, 0.0);
	modelViewMatrix *= Matrix::getRotationMatrix(M_PI / 2, 0.0f, 1.0f, 0.0f);

More complex models may exceed internal limits in librender.  The README in 
software/librender has a section 'Limits' that describes how to remedy this.
