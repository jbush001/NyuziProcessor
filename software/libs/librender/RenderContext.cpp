//
// Copyright 2011-2015 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include <schedule.h>
#include <string.h>
#include "line.h"
#include "Rasterizer.h"
#include "RenderContext.h"
#include "TriangleFiller.h"
#include "SIMDMath.h"

namespace librender
{

RenderContext::RenderContext(size_t workingMemSize)
    : 	fClearColorBuffer(false),
       fAllocator(workingMemSize)
{
    fDrawQueue.setAllocator(&fAllocator);
}

void RenderContext::setClearColor(float r, float g, float b)
{
    r = max(min(r, 1.0f), 0.0f);
    g = max(min(g, 1.0f), 0.0f);
    b = max(min(b, 1.0f), 0.0f);

    fClearColor = 0xff000000 | (unsigned(b * 255.0) << 16) | (unsigned(g * 255.0) << 8)
                  | unsigned(r * 255.0);
}

void RenderContext::bindVertexAttrs(const RenderBuffer *vertexAttrs)
{
    fCurrentState.fVertexAttrBuffer = vertexAttrs;
}

void RenderContext::bindUniforms(const void *uniforms, size_t size)
{
    void *uniformCopy = fAllocator.alloc(size);
    ::memcpy(uniformCopy, uniforms, size);
    fCurrentState.fUniforms = uniformCopy;
}

void RenderContext::bindTarget(RenderTarget *target)
{
    fRenderTarget = target;
    fFbWidth = fRenderTarget->getColorBuffer()->getWidth();
    fFbHeight = fRenderTarget->getColorBuffer()->getHeight();
    fTileColumns = (fFbWidth + kTileSize - 1) / kTileSize;
    fTileRows = (fFbHeight + kTileSize - 1) / kTileSize;
}

void RenderContext::bindShader(Shader *shader)
{
    fCurrentState.fShader = shader;
    fCurrentState.fParamsPerVertex = fCurrentState.fShader->getNumParams();
}

void RenderContext::drawElements(const RenderBuffer *indices)
{
    fCurrentState.fIndexBuffer = indices;
    fDrawQueue.append(fCurrentState);
}

void RenderContext::_shadeVertices(void *_castToContext, int index)
{
    static_cast<RenderContext*>(_castToContext)->shadeVertices(index);
}

void RenderContext::_setUpTriangle(void *_castToContext, int index)
{
    static_cast<RenderContext*>(_castToContext)->setUpTriangle(index);
}

void RenderContext::_fillTile(void *_castToContext, int index)
{
    static_cast<RenderContext*>(_castToContext)->fillTile(index);
}

void RenderContext::_wireframeTile(void *_castToContext, int index)
{
    static_cast<RenderContext*>(_castToContext)->wireframeTile(index);
}

void RenderContext::finish()
{
    int kMaxTiles = fTileColumns * fTileRows;
    fTiles = new (fAllocator) TriangleArray[kMaxTiles];
    for (int i = 0; i < kMaxTiles; i++)
        fTiles[i].setAllocator(&fAllocator);

    // Geometry phase.  Walk through each draw command and perform two steps
    // for each one:
    // 1. Call vertex shader on attributes (shadeVertices)
    // 2. Perform triangle setup and binning (setUpTriangle)
    fBaseSequenceNumber = 0;
    for (fRenderCommandIterator = fDrawQueue.begin(); fRenderCommandIterator != fDrawQueue.end();
            ++fRenderCommandIterator)
    {
        RenderState &state = *fRenderCommandIterator;
        int numVertices = state.fVertexAttrBuffer->getNumElements();
        int numTriangles = state.fIndexBuffer->getNumElements() / 3;
        state.fVertexParams = static_cast<float*>(fAllocator.alloc(
                                  static_cast<unsigned int>(numVertices)
                                  * static_cast<unsigned int>(state.fShader->getNumParams())
                                  * sizeof(int)));
        parallel_execute(_shadeVertices, this, (numVertices + 15) / 16);
        parallel_execute(_setUpTriangle, this, numTriangles);
        fBaseSequenceNumber += numTriangles;
    }

    // Pixel phase.  Shade the pixels and write back.
    if (fWireframeMode)
        parallel_execute(_wireframeTile, this, fTileColumns * fTileRows);
    else
        parallel_execute(_fillTile, this, fTileColumns * fTileRows);

#if DISPLAY_STATS
    printf("total triangles = %d\n", fBaseSequenceNumber);
    printf("used %zu bytes\n", fAllocator.bytesUsed());
#endif

    // Clean up memory
    // First reset draw queue to clean up, then allocator, which frees
    // memory it is using.
    fDrawQueue.reset();
    fAllocator.reset();
    fCurrentState.fUniforms = nullptr;	// Remove dangling pointer
    fClearColorBuffer = false;
}

//
// Compute vertex parameters.  This shades all vertices in the attribute array,
// even if they are not referenced by the index array.
//
void RenderContext::shadeVertices(int index)
{
    const RenderState &state = *fRenderCommandIterator;
    int numVertices = state.fVertexAttrBuffer->getNumElements() - index * 16;
    vmask_t mask;
    if (numVertices < 16)
        mask = (1 << numVertices) - 1;
    else
        mask = 0xffff;

    int attribsPerVertex = state.fShader->getNumAttribs();
    vecf16_t packedAttribs[attribsPerVertex];
    int startIndex = index * 16;
    for (int attrib = 0; attrib < attribsPerVertex; attrib++)
    {
        packedAttribs[attrib] = vecf16_t(state.fVertexAttrBuffer->gatherElements(startIndex,
                                         attrib, mask));
    }

    int paramsPerVertex = state.fShader->getNumParams();
    vecf16_t packedParams[paramsPerVertex];
    state.fShader->shadeVertices(packedParams, packedAttribs, state.fUniforms, mask);

    const veci16_t kStepVector = { 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60 };
    const veci16_t paramStepVector = kStepVector * paramsPerVertex;
    float *outBuf = state.fVertexParams + paramsPerVertex * index * 16;
    veci16_t paramPtr = paramStepVector + reinterpret_cast<int>(outBuf);
    for (int param = 0; param < paramsPerVertex; param++)
    {
        __builtin_nyuzi_scatter_storef_masked(paramPtr, packedParams[param], mask);
        paramPtr += 4;
    }
}

namespace
{

const float kNearWClip = 1.0;

void interpolate(float *outParams, const float *inParams0, const float *inParams1, int numParams,
                 float distance)
{
    for (int i = 0; i < numParams; i++)
        outParams[i] = inParams0[i] * (1.0 - distance) + inParams1[i] * distance;
}

} // namespace

//
// Clip a triangle where one vertex is past the near clip plane.
// The clipped vertex is always params0.  This creates two new triangles above
// the clip plane.
//
//    1 +-------+ 2
//      | \    /
//      |   \ /
//  np1 +----+ np2
//      |.../
//      |../    clipped
//      |./
//      |/
//      0
//

void RenderContext::clipOne(int sequence, const RenderState &state, const float *params0,
                            const float *params1, const float *params2)
{
    float newPoint1[kMaxParams];
    float newPoint2[kMaxParams];

    interpolate(newPoint1, params1, params0, state.fParamsPerVertex, (params1[kParamW] - kNearWClip)
                / (params1[kParamW] - params0[kParamW]));
    interpolate(newPoint2, params2, params0, state.fParamsPerVertex, (params2[kParamW] - kNearWClip)
                / (params2[kParamW] - params0[kParamW]));
    enqueueTriangle(sequence, state, newPoint1, params1, newPoint2);
    enqueueTriangle(sequence, state, newPoint2, params1, params2);
}

//
// Clip a triangle where two vertices are past the near clip plane.
// The clipped vertices are always param0 and params1. Adjust the
// bottom two points of the triangle.
//
//                 2
//                 +
//               / |
//              /  |
//             /   |
//        np1 +----+ np2
//           /.....|
//          /......|  clipped
//         /.......|
//        +--------+
//        1        0
//

void RenderContext::clipTwo(int sequence, const RenderState &state, const float *params0,
                            const float *params1, const float *params2)
{
    float newPoint1[kMaxParams];
    float newPoint2[kMaxParams];

    interpolate(newPoint1, params2, params1, state.fParamsPerVertex, (params2[kParamW] - kNearWClip)
                / (params2[kParamW] - params1[kParamW]));
    interpolate(newPoint2, params2, params0, state.fParamsPerVertex, (params2[kParamW] - kNearWClip)
                / (params2[kParamW] - params0[kParamW]));
    enqueueTriangle(sequence, state, newPoint2, newPoint1, params2);
}

void RenderContext::setUpTriangle(int triangleIndex)
{
    RenderState &state = *fRenderCommandIterator;
    int vertexIndex = triangleIndex * 3;
    const int *indices = static_cast<const int*>(state.fIndexBuffer->getData());
    int offset0 = indices[vertexIndex] * state.fParamsPerVertex;
    int offset1 = indices[vertexIndex + 1] * state.fParamsPerVertex;
    int offset2 = indices[vertexIndex + 2] * state.fParamsPerVertex;
    const float *params0 = &state.fVertexParams[offset0];
    const float *params1 = &state.fVertexParams[offset1];
    const float *params2 = &state.fVertexParams[offset2];

    // Determine which point (if any) are clipped against the near plane, call
    // appropriate clip routine with triangle rotated appropriately. We don't
    // clip against other planes.
    // XXX This is not quite correct; it needs to perform homogenous clipping.  Also,
    // the viewing volume is zNear = -1, zFar = -inf
    int clipMask = (params0[kParamW] < kNearWClip ? 1 : 0) | (params1[kParamW] < kNearWClip ? 2 : 0)
                   | (params2[kParamW] < kNearWClip ? 4 : 0);
    switch (clipMask)
    {
    case 0:
        // Not clipped at all.
        enqueueTriangle(fBaseSequenceNumber + triangleIndex, state,
                        params0, params1, params2);
        break;

    case 1:
        clipOne(fBaseSequenceNumber + triangleIndex, state, params0, params1, params2);
        break;

    case 2:
        clipOne(fBaseSequenceNumber + triangleIndex, state, params1, params2, params0);
        break;

    case 4:
        clipOne(fBaseSequenceNumber + triangleIndex, state, params2, params0, params1);
        break;

    case 3:
        clipTwo(fBaseSequenceNumber + triangleIndex, state, params0, params1, params2);
        break;

    case 6:
        clipTwo(fBaseSequenceNumber + triangleIndex, state, params1, params2, params0);
        break;

    case 5:
        clipTwo(fBaseSequenceNumber + triangleIndex, state, params2, params0, params1);
        break;

        // Else is totally clipped, ignore
    }
}

//
// Performs the second half of triangle setup after clipping: perspective
// division, backface culling, and binning.
//

void RenderContext::enqueueTriangle(int sequence, const RenderState &state, const float *params0,
                                    const float *params1, const float *params2)
{
    Triangle tri;
    tri.sequenceNumber = sequence;
    tri.state = &state;

    // Perform perspective division.
    // XXX Z should be divided against W here.  This is a bit of a hack.
    float oneOverW0 = 1.0 / params0[kParamW];
    float oneOverW1 = 1.0 / params1[kParamW];
    float oneOverW2 = 1.0 / params2[kParamW];
    tri.x0 = params0[kParamX] * oneOverW0;
    tri.y0 = params0[kParamY] * oneOverW0;
    tri.z0 = params0[kParamZ];
    tri.x1 = params1[kParamX] * oneOverW1;
    tri.y1 = params1[kParamY] * oneOverW1;
    tri.z1 = params1[kParamZ];
    tri.x2 = params2[kParamX] * oneOverW2;
    tri.y2 = params2[kParamY] * oneOverW2;
    tri.z2 = params2[kParamZ];

    // Convert screen space coordinates to raster coordinates
    int halfWidth = fFbWidth / 2;
    int halfHeight = fFbHeight / 2;
    tri.x0Rast = tri.x0 * halfWidth + halfWidth;
    tri.y0Rast = -tri.y0 * halfHeight + halfHeight;
    tri.x1Rast = tri.x1 * halfWidth + halfWidth;
    tri.y1Rast = -tri.y1 * halfHeight + halfHeight;
    tri.x2Rast = tri.x2 * halfWidth + halfWidth;
    tri.y2Rast = -tri.y2 * halfHeight + halfHeight;

    int winding = (tri.x1Rast - tri.x0Rast) * (tri.y2Rast - tri.y0Rast) - (tri.y1Rast - tri.y0Rast)
                  * (tri.x2Rast - tri.x0Rast);
    if (winding == 0)
        return;	// remove edge-on triangles, which won't be rasterized correctly.

    tri.woundCCW = winding < 0;

    // Backface culling
    if ((state.cullingMode == RenderState::kCullCW && !tri.woundCCW)
            || (state.cullingMode == RenderState::kCullCCW && tri.woundCCW))
        return;

    // Compute bounding box
    int bbLeft = tri.x0Rast < tri.x1Rast ? tri.x0Rast : tri.x1Rast;
    bbLeft = tri.x2Rast < bbLeft ? tri.x2Rast : bbLeft;
    int bbTop = tri.y0Rast < tri.y1Rast ? tri.y0Rast : tri.y1Rast;
    bbTop = tri.y2Rast < bbTop ? tri.y2Rast : bbTop;
    int bbRight = tri.x0Rast > tri.x1Rast ? tri.x0Rast : tri.x1Rast;
    bbRight = tri.x2Rast > bbRight ? tri.x2Rast : bbRight;
    int bbBottom = tri.y0Rast > tri.y1Rast ? tri.y0Rast : tri.y1Rast;
    bbBottom = tri.y2Rast > bbBottom ? tri.y2Rast : bbBottom;

    // Cull triangles that are outside the sides of the view frustum
    if (bbRight < 0 || bbLeft >= fFbWidth || bbBottom < 0 || bbTop >= fFbHeight)
        return;

    // Copy parameters into triangle structure, skipping position which is already
    // in x0/y0/z0/x1...
    unsigned int paramSize = sizeof(float) * static_cast<unsigned int>(state.fParamsPerVertex - 4);
    float *params = static_cast<float*>(fAllocator.alloc(paramSize * 3));
    memcpy(params, params0 + 4, paramSize);
    memcpy(params + state.fParamsPerVertex - 4, params1 + 4, paramSize);
    memcpy(params + (state.fParamsPerVertex - 4) * 2, params2 + 4, paramSize);
    tri.params = params;

    // Determine which tiles this triangle may overlap with a simple
    // bounding box check.  Enqueue it in the queues for each tile.
    int minTileX = max(bbLeft / kTileSize, 0);
    int maxTileX = min(bbRight / kTileSize, fTileColumns - 1);
    int minTileY = max(bbTop / kTileSize, 0);
    int maxTileY = min(bbBottom / kTileSize, fTileRows - 1);
    for (int tiley = minTileY; tiley <= maxTileY; tiley++)
    {
        for (int tilex = minTileX; tilex <= maxTileX; tilex++)
            fTiles[tiley * fTileColumns + tilex].append(tri);
    }
}

namespace
{

// These assume counterclockwise winding
bool edgeRejected(int left, int top, int right, int bottom,
                  int x1, int y1, int x2, int y2)
{
    // Find a reject corner
    int cx = y2 > y1 ? right : left;
    int cy = x2 > x1 ? top : bottom;

    return (x2 - x1) * (cy - y1) - (y2 - y1) * (cx - x1) > 0;
}

bool triangleRejected(int left, int top, int right, int bottom,
                      int x1, int y1, int x2, int y2, int x3, int y3)
{
    return edgeRejected(left, top, right, bottom, x1, y1, x2, y2)
           || edgeRejected(left, top, right, bottom, x2, y2, x3, y3)
           || edgeRejected(left, top, right, bottom, x3, y3, x1, y1);
}

} // namespace

void RenderContext::fillTile(int index)
{
    const int x = index % fTileColumns;
    const int y = index / fTileColumns;
    const int tileX = x * kTileSize;
    const int tileY = y * kTileSize;
    TriangleArray &tile = fTiles[y * fTileColumns + x];
    Surface *colorBuffer = fRenderTarget->getColorBuffer();

    if (fClearColorBuffer)
        colorBuffer->clearTile(tileX, tileY, fClearColor);

    // Initialize Z-Buffer to -infinity
    if (fRenderTarget->getDepthBuffer())
        fRenderTarget->getDepthBuffer()->clearTile(tileX, tileY, 0xff800000);

    // The triangles may have been reordered during the parallel vertex shading
    // phase.  Put them back in the order they were submitted.
    tile.sort();

    // Walk through all triangles that overlap this tile and render
    TriangleFiller filler(fRenderTarget);
    for (const Triangle &tri : tile)
    {
        const RenderState &state = *tri.state;

        // Do a better check to see if this triangle overlaps the tile.
        // If not, skip setting up interpolators.
        if (tri.woundCCW)
        {
            if (triangleRejected(tileX, tileY, tileX + kTileSize,
                                 tileY + kTileSize, tri.x0Rast, tri.y0Rast, tri.x1Rast,
                                 tri.y1Rast, tri.x2Rast, tri.y2Rast))
            {
                continue;
            }
        }
        else
        {
            if (triangleRejected(tileX, tileY, tileX + kTileSize,
                                 tileY + kTileSize, tri.x0Rast, tri.y0Rast, tri.x2Rast,
                                 tri.y2Rast, tri.x1Rast, tri.y1Rast))
            {
                continue;
            }
        }

        // Set up parameters and rasterize triangle.
        filler.setUpTriangle(&state, tri.x0, tri.y0, tri.z0, tri.x1, tri.y1, tri.z1, tri.x2,
                             tri.y2, tri.z2);
        for (int paramI = 0; paramI < state.fParamsPerVertex; paramI++)
        {
            filler.setUpParam(tri.params[paramI],
                              tri.params[(state.fParamsPerVertex - 4) + paramI],
                              tri.params[(state.fParamsPerVertex - 4) * 2 + paramI]);
        }

        if (tri.woundCCW)
        {
            fillTriangle(filler, tileX, tileY,
                         tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast,
                         fFbWidth, fFbHeight);
        }
        else
        {
            fillTriangle(filler, tileX, tileY,
                         tri.x0Rast, tri.y0Rast, tri.x2Rast, tri.y2Rast, tri.x1Rast, tri.y1Rast,
                         fFbWidth, fFbHeight);
        }
    }

    colorBuffer->flushTile(tileX, tileY);
}

//
// Fill a tile, except with wireframe only
//

void RenderContext::wireframeTile(int index)
{
    const int x = index % fTileColumns;
    const int y = index / fTileColumns;
    const int tileX = x * kTileSize;
    const int tileY = y * kTileSize;
    const TriangleArray &tile = fTiles[y * fTileColumns + x];

    Surface *colorBuffer = fRenderTarget->getColorBuffer();
    colorBuffer->clearTile(tileX, tileY, fClearColor);
    int bottomClip = tileY + kTileSize - 1;
    int rightClip = tileX + kTileSize - 1;
    if (bottomClip >= colorBuffer->getHeight())
        bottomClip = colorBuffer->getHeight() - 1;

    if (rightClip >= colorBuffer->getWidth())
        rightClip = colorBuffer->getWidth() - 1;

    for (const Triangle &tri : tile)
    {
        drawLineClipped(colorBuffer, tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, 0xffffffff,
                        tileX, tileY, rightClip, bottomClip);
        drawLineClipped(colorBuffer, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast, 0xffffffff,
                        tileX, tileY, rightClip, bottomClip);
        drawLineClipped(colorBuffer, tri.x2Rast, tri.y2Rast, tri.x0Rast, tri.y0Rast, 0xffffffff,
                        tileX, tileY, rightClip, bottomClip);
    }

    colorBuffer->flushTile(tileX, tileY);
}

} // namespace librender