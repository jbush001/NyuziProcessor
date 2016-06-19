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


//
// Validate multiple level-of-detail textures by rendering a square
// that stretches far into the Z direction. Each mip level is a different
// color to show where the level changes.
//

#include <math.h>
#include <Matrix.h>
#include <nyuzi.h>
#include <RenderContext.h>
#include <RenderTarget.h>
#include <schedule.h>
#include <stdlib.h>
#include <Texture.h>
#include <vga.h>
#include "TextureShader.h"

using namespace librender;

const int kFbWidth = 640;
const int kFbHeight = 480;

static float kSquareVertices[] =
{
    -3.0, -3.0, -25.0,  0.0, 0.0,
    -3.0, -3.0, -1.0,    0.0, 1.0,
    3.0,  -3.0, -1.0,     1.0, 1.0,
    3.0,  -3.0, -25.0,   1.0, 0.0,
};

static int kSquareIndices[] = { 0, 1, 2, 2, 3, 0 };

Texture *makeMipMaps()
{
    const unsigned int kColors[] =
    {
        0xff0000ff,	// Red
        0xff00ff00,	// Blue
        0xffff0000, // Green
        0xff00ffff, // Yellow
    };

    Texture *texture = new Texture();
    for (int i = 0; i < 4; i++)
    {
        int mipSize = 512 >> i;
        Surface *mipSurface = new Surface(mipSize, mipSize);
        unsigned int *bits = static_cast<unsigned int*>(mipSurface->bits());
        unsigned int color = kColors[i];
        for (int y = 0; y < mipSize; y++)
        {
            for (int x = 0; x < mipSize; x++)
            {
                if (((x ^ y) >> (5 - i)) & 1)
                    bits[y * mipSize + x] = 0;
                else
                    bits[y * mipSize + x] = color;
            }
        }

        texture->setMipSurface(i, mipSurface);
        mipSize /= 2;
    }

    return texture;
}

// All threads start execution here.
int main()
{
    void *frameBuffer;
    if (get_current_thread_id() != 0)
        worker_thread();

    // Set up render context
    frameBuffer = init_vga(VGA_MODE_640x480);

    start_all_threads();

    Texture *texture = makeMipMaps();
    texture->enableBilinearFiltering(true);

    RenderContext *context = new RenderContext();
    RenderTarget *renderTarget = new RenderTarget();
    Surface *colorBuffer = new Surface(kFbWidth, kFbHeight, frameBuffer);
    renderTarget->setColorBuffer(colorBuffer);
    context->bindTarget(renderTarget);
    context->clearColorBuffer();
    context->bindShader(new TextureShader());
    context->bindTexture(0, texture);
    TextureUniforms uniforms;
    uniforms.fMVPMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);
    context->bindUniforms(&uniforms, sizeof(uniforms));
    const RenderBuffer kVertices(kSquareVertices, 4, 5 * sizeof(float));
    const RenderBuffer kIndices(kSquareIndices, 6, sizeof(int));
    context->bindVertexAttrs(&kVertices);
    context->drawElements(&kIndices);
    context->finish();

    return 0;
}
