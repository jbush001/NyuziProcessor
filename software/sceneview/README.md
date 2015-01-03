This is a viewer for Wavefront .OBJ files. It can be executed in the emulator
by typing:

    make run
    
This will execute the 'make_resource_py.py' script, which will read the OBJ file
and associated texture graphics (The script is selected with the MODEL_FILE variable
in the makefile) and write out a new file 'resource.bin'.  The emulator will
load this as a virtual block device, which the viewer will read and render. 

To view other models, delete 'resource.bin, change MODEL_FILE to point at the OBJ file
for the new model and type `make run` again.

