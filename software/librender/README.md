This is a 3D rendering library that attempts to fully exploit hardware 
multithreading and SIMD. 

# Pipeline

## Geometry Phase
There are two steps to this, which execute in sequence for each draw call
in the queue. Each one finishes completely before the next starts.

1. The vertex shader is run on input vertex attributes.  It produces 
an array of output vertex parameters.  Vertices are divided between threads, 
each of which processes 16 at a time (one vertex per vector lane). There are 
up to 64 vertices in progress simultaneously per core (16 vertices times 
four threads). This phase does not look at the index buffer, but blindly 
computes all vertices in the array.

2. Triangle setup is done for each set of 3 indices in the index buffer.  This
is done with scalar code, but is distributed across threads:

 - Clip triangles against near plane (potentially dividing into multiple triangles)
 - Cull triangles that are facing away from the camera
 - Convert from screen space to raster coordinates. 
 - Insert triangles in tile queues using bounding boxes

## Pixel Phase
This phase starts after the geometry phase is completely finished. Each thread 
completely renders a 64x64 tile of the render target:

- Sort: Since the geometry phase runs in parallel, triangles will end up in the tile's 
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
  
# Limits

There are hardcoded limits in a number of places in the pipeline that may trip
asserts with more complex scenes.

### Draw Queue/Tile Queue

    ASSERT FAILED: ./SliceArray.h:78: index < MAX_BUCKETS * BUCKET_SIZE

If there is an issue with the tile queue, this may occur on several threads simultaneously
and look like this:

    AASSSSEERRTT  FFAAIAILSLEASEDSED:SR: ET R TF AFIALIE./L.DS/lES:ilciDe cAe:rArra rya.yh.h::./Sli.c/eSAlrircaeyA.rhray.:h:7878::  i7n8idned:x7e 8x<   <:M AMX A_XB_UBCUKCEKTEST S*  i*Bn UdBCeUKxCiE KnT<Ed_ TeSM_xIAS ZXI<E_Z BEMUA

If this is a problem with the command queue (which limits the number of calls to submitDrawCall() in
a frame), it can be adjusted in RenderContext.h

	SliceArray<DrawState, 32, 16> fDrawQueue;

The total allowed draw commands is 32 * 16 in this example. Increasing either of the numbers in the
template will increase the total limit.
 
If the limit is the individual tile queues, they can also be adjusted in RenderContext.h:

	typedef SliceArray<Triangle, 8, 32> TriangleArray;

### Slice Allocator Limit

    ASSERT FAILED: ./SliceAllocator.h:60: alignedAlloc + size < fArenaBase + fTotalSize

The slice allocator allocates temporary, short-lived structures during rendering.  It can be increased
in SliceAllocator.h:

	SliceAllocator(int arenaSize = 0x800000)