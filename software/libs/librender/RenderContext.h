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


#pragma once

#include "CommandQueue.h"
#include "RegionAllocator.h"
#include "RenderState.h"
#include "RenderTarget.h"
#include "Shader.h"

namespace librender
{

//
// Interface for client applications to enqueue rendering commands.
// State set with bindXXX will apply for any drawing calls
// invoked after until the next bind of the same attribute.
//
class RenderContext
{
public:
    explicit RenderContext(unsigned int workingMemSize = 0x400000);
    RenderContext(const RenderContext&) = delete;
    RenderContext& operator=(const RenderContext&) = delete;

    void setClearColor(float r, float g, float b);

    void clearColorBuffer()
    {
        fClearColorBuffer = true;
    }

    // Set where rendered raster data should be written
    void bindTarget(RenderTarget *target);

    // Set a Shader that will be called for all pixels rendered
    // after the call.
    void bindShader(Shader *shader);

    // Set interpolated vertex attributes for next draw call.
    void bindVertexAttrs(const RenderBuffer *vertexAttrs);

    // This texture will be passed to pixel shaders for all triangles
    // rendered after this call.
    void bindTexture(int textureIndex, Texture *texture)
    {
        fCurrentState.fTextures[textureIndex] = texture;
    }

    // The uniforms array is passed to shaders and is used for values
    // that are constant for all pixels.
    // XXX Unlike other state changes, this will be invalidated when finish()
    // is called. You will need to call it again for the next frame.
    void bindUniforms(const void *uniforms, size_t size);

    // If enabled is true, this will
    // - Update the depth buffer for each pixel covered by triangles
    // - Perform a depth test and reject any pixels that do not match.
    void enableDepthBuffer(bool enabled)
    {
        fCurrentState.fEnableDepthBuffer = enabled;
    }

    // If this is true, the alpha value will be used to blend newly written
    // pixels with values already in the framebuffer. If false, newly
    // written pixels will replace old ones.
    void enableBlend(bool enabled)
    {
        fCurrentState.fEnableBlend = enabled;
    }

    // Draw primitives using currently configured state set by bindXXX calls.
    // Indices reference into bound vertex attribute buffer.
    void drawElements(const RenderBuffer *indices);

    // Execute all submitted drawing commands. No rendering occurs until
    // this is called.
    void finish();

    // If this is set, no pixels will be rendered, but lines will be drawn at the
    // edge of rendered triangles.
    void enableWireframeMode(bool enable)
    {
        fWireframeMode = enable;
    }

    void setCulling(RenderState::CullingMode mode)
    {
        fCurrentState.cullingMode = mode;
    }

private:
    struct Triangle
    {
        int sequenceNumber;
        const RenderState *state;
        float x0, y0, z0, x1, y1, z1, x2, y2, z2;
        int x0Rast, y0Rast, x1Rast, y1Rast, x2Rast, y2Rast;
        const float *params;
        bool woundCCW;
        bool operator>(const Triangle &tri) const
        {
            return sequenceNumber > tri.sequenceNumber;
        }
    };

    void shadeVertices(int index);
    void setUpTriangle(int triangleIndex);
    void fillTile(int index);
    void wireframeTile(int index);
    static void _shadeVertices(void *_castToContext, int index);
    static void _setUpTriangle(void *_castToContext, int index);
    static void _fillTile(void *_castToContext, int index);
    static void _wireframeTile(void *_castToContext, int index);
    void clipOne(int sequence, const RenderState &command, const float *params0, const float *params1,
                 const float *params2);
    void clipTwo(int sequence, const RenderState &command, const float *params0, const float *params1,
                 const float *params2);
    void enqueueTriangle(int sequence, const RenderState &command, const float *params0,
                         const float *params1, const float *params2);

    typedef CommandQueue<Triangle, 64> TriangleArray;
    typedef CommandQueue<RenderState, 32> DrawQueue;

    bool fClearColorBuffer;
    RenderTarget *fRenderTarget = nullptr;
    TriangleArray *fTiles = nullptr;
    int fFbWidth = 0;
    int fFbHeight = 0;
    int fTileColumns = 0;
    int fTileRows = 0;
    RegionAllocator fAllocator;
    RenderState fCurrentState;
    DrawQueue fDrawQueue;
    DrawQueue::iterator fRenderCommandIterator = fDrawQueue.end();
    int fBaseSequenceNumber = 0;
    unsigned int fClearColor = 0xff000000;
    bool fWireframeMode = false;
};

} // namespace librender
