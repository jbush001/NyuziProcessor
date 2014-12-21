This is a simple 3D rendering engine. There are a few phases to the 
rendering pipeline. At the end of each phase, threads will  wait until all other 
threads are finished.  The pipeline is structured as follows:

### Geometry Phase
The vertex shader is run on sets of input vertex attributes.  It produces 
an array of output vertex parameters.  Vertices are divided between threads, each of 
which processes 16 at a time (one vertex per vector lane). There are up to 64 
vertices in progress simultaneously per core (16 vertices times four threads).  

### Triangle Setup Phase
- Backface cull triangles that are facing away from the camera
- Convert from screen space to raster coordinates. 

### Pixel Phase
Each thread works on a single 64x64 tile of the screen at a time. 

- Do a bounding box check to skip triangles that don't overlap the current tile.
- Rasterize: Recursively subdivide triangles to 4x4 squares (16 pixels). The remaining stages work on 16 pixels at a time with one pixel per vector lane.
- Z-Buffer/early reject: Interpolate the z value for each pixel, reject ones that are occluded, and update the Z-buffer.
- Parameter interpolation: Interpolated vertex parameters in a perspective correct manner for each pixel, to be passed to the pixel shader.
- Pixel shading: determine the colors for each of the pixels.
- Blend/writeback: If alpha is enabled, blend here (reject pixels where the alpha is zero). Write 
  color values into framebuffer.

The frame buffer is hard coded at location 0x200000 (2MB).

# To do
- Add near plane clipping.  Currently, when triangle points are at or behind the camera,
it will draw really odd things.  Need to adjust the triangle in this case, potentially 
splitting into two.
- Ability to have state changes.  Need proper command queue rather than hard coded
state in main.

