This is a 3D rendering library that utilizes hardware multithreading and SIMD.

Thread 0 sets up the scene, submitting draw commands using the RenderContext
interface. When it has submitted all commands it calls RenderContext::finish()
to render the scene. This spins up all other hardware worker threads using the
function parallelExecute() in libos.

This is a tile based renderer, also known as a sort-middle architecture. It
divides the destination into fixed size rectangles. Threads render each tile
completely before moving to the next. This approach has a few advantages:
* It allows splitting the work across many threads. Because each thread
  exclusively owns a tile, there is no locking required to preserve pixel
  ordering, which minimizes synchronization overhead.
* It reduces external memory bandwidth, as the tiles that it is actively
  rendering fit in the L2 cache.

# Pipeline

Rendering occurs in two phases:

## Geometry Phase
This phase has two steps, which execute in sequence for each draw call.
Each step finishes completely before the next starts.

1. The vertex shader processes vertex attributes, outputting
vertex parameters. The renderer divides vertices among threads. Each thread
processes 16 at a time (one for each vector lane). There are up to 64 vertices
in progress at once for each core (16 vertices times four threads). This phase
does not look at the index buffer, but computes all vertices in the array.

2. Set up triangles. This is scalar, but divided among threads. This phase
builds a list of triangles that potentially cover each tile. It also:

 - Clips triangles against the near plane (potentially splitting into multiple
   triangles)
 - Culls triangles that are facing away from the camera
 - Converts from screen space to raster coordinates.
 - Insert triangles in tile queues using a bounding box test.

## Pixel Phase
This phase starts after the geometry phase finishes. Each thread
renders a 64x64 tile of the render target at a time, using the tile's triangle
list that the previous phase created. It also performs:

- Triangle list sorting. Because the geometry phase runs in parallel, triangles
  will end up in the tile's queue in arbitrary order. Put them back in submit
  order.
- Triangle rasterization. Recursively subdivide triangles to 4x4 squares
  (16 pixels). The remaining stages work on 16 pixels at a time with one pixel
  for each vector lane.
- Z-Buffer/early reject: Interpolate the z value for each pixel, reject occluded
  pixels, and write back to the Z-buffer.
- Parameter interpolation: Interpolate vertex parameters in a perspective correct
  manner for each pixel and pass them to the pixel shader.
- Pixel shading: determine the colors for each of the pixels. This may
  optionally call into the texture sampler.
- Blending/writeback: If alpha is enabled, blend. Reject pixels where the
  alpha is zero. Write color values into framebuffer.

# Limits

The region allocator allocates temporary, short-lived structures during rendering.
It has a hardcoded size that may trip asserts with more complex scenes.

    ASSERT FAILED: ./RegionAllocator.h:60: alignedAlloc + size < fArenaBase + fTotalSize

The RenderContext constructor takes the size of this arena as a parameter.
