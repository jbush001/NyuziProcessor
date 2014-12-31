This is a simple 3D rendering engine. There are a few phases to the 
rendering pipeline. At the end of each phase, threads will  wait until 
all other threads are finished. The pipeline is structured as follows:

### Geometry Phase
There are two steps to this, which execute in sequence for each draw call
in the queue.

1. The vertex shader is run on input vertex attributes.  It produces 
an array of output vertex parameters.  Vertices are divided between threads, 
each of which processes 16 at a time (one vertex per vector lane). There are 
up to 64 vertices in progress simultaneously per core (16 vertices times 
four threads). This phase does not look at the index buffer, but blindly 
compates all vertices in the array.

2. Triangle setup is done for each set of 3 indices in the index buffer.  This
is done with scalar code, but is distributed across threads:

 - Backface cull triangles that are facing away from the camera
 - Convert from screen space to raster coordinates. 
 - Assign triangles to tiles using bounding boxes

### Pixel Phase
Each thread completely renders a 64x64 tile of the render target:

- Sort: Since the geometry phase runs in parallel, these will end up in the tile's 
  queue in arbitrary order. Put them back in submit order.
- Rasterize: Recursively subdivide triangles to 4x4 squares (16 pixels). The 
  remaining stages work on 16 pixels at a time with one pixel per vector lane.
- Z-Buffer/early reject: Interpolate the z value for each pixel, reject ones 
  that are occluded, and update the Z-buffer.
- Parameter interpolation: Interpolated vertex parameters in a perspective 
  correct manner for each pixel, to be passed to the pixel shader.
- Pixel shading: determine the colors for each of the pixels. This may
  optionally call into the texture sampler.
- Blend/writeback: If alpha is enabled, blend here (reject pixels where the 
  alpha is zero). Write color values into framebuffer.


