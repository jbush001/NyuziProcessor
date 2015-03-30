This is a 3D rendering library that attempts to fully exploit hardware 
multithreading and SIMD. 

Thread 0 is responsible for setting up the scene.  RenderContext is the 
primary interface for submitting draw commands.  When all commands have been 
submitted, thread 0 calls RenderContext::finish() which renders the 
scene.   This will spin up all other hardware worker threads using the function
parallelExecute() in libos.a.

This is a tile based renderer, also known as a sort-middle architecture.  The
output surface is broken into fixed size tiles, each of which is rendered 
completely.  This has two main advantages:
 - It allows splitting the work across a large number of threads. Because 
   each thread owns the entire tile, there is no locking required to preserve
   pixel ordering, reducing overhead.
 - It reduces external memory bandwidth, since the actively rendered tiles can
   fit entirely in the L2 cache.

# Pipeline

There are two phases in the rendering pipeline.

## Geometry Phase
There are two steps to this, which execute in sequence for each draw call
in the queue. Each one finishes completely before the next starts.

1. The vertex shader is run on input vertex attributes.  It produces 
an array of output vertex parameters.  Vertices are divided between threads, 
each of which processes 16 at a time (one vertex per vector lane). There are 
up to 64 vertices in progress simultaneously per core (16 vertices times 
four threads). This phase does not look at the index buffer, but computes 
all vertices in the array.

2. Triangle setup is done for each set of 3 indices in the index buffer.  This
is done with scalar code, but is distributed across threads. Each tile has a
separate list of triangles that cover it, which this phase will append to.

 - Clip triangles against near plane (potentially dividing into multiple triangles)
 - Cull triangles that are facing away from the camera
 - Convert from screen space to raster coordinates. 
 - Insert triangles in tile queues using bounding boxes

## Pixel Phase
This phase starts after the geometry phase is completely finished. Each thread 
completely renders a 64x64 tile of the render target, using the bin's list of 
triangles that was created in the previous phase.

- Sort: Since the geometry phase runs in parallel, triangles will end up in the tile's 
  queue in arbitrary order. Put them back in submit order.
- Rasterize: Recursively subdivide triangles to 4x4 squares (16 pixels). The 
  remaining stages work on 16 pixels at a time with one pixel per vector lane.
- Z-Buffer/early reject: Interpolate the z value for each pixel, reject ones 
  that are occluded, and write back to the Z-buffer.
- Parameter interpolation: Interpolated vertex parameters in a perspective 
  correct manner for each pixel, to be passed to the pixel shader.
- Pixel shading: determine the colors for each of the pixels. This may
  optionally call into the texture sampler.
- Blend/writeback: If alpha is enabled, blend here (reject pixels where the 
  alpha is zero). Write color values into framebuffer.
  
# Limits

The slice allocator allocates temporary, short-lived structures during rendering. It
has a hardcoded size that may trip asserts with more complex scenes.

    ASSERT FAILED: ./SliceAllocator.h:60: alignedAlloc + size < fArenaBase + fTotalSize

The size of this arena is specified in the constructor to RenderContext.
