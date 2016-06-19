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
// Validate texture mapping by displaying a texture on the sides of a cube.
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
#include "test_texture.h"
#include "cube.h"

using namespace librender;

const int kFbWidth = 640;
const int kFbHeight = 480;

// All threads start execution here.
int main()
{
    void *frameBuffer;
    if (get_current_thread_id() != 0)
        worker_thread();

    frameBuffer = init_vga(VGA_MODE_640x480);

    start_all_threads();

    RenderContext *context = new RenderContext();
    RenderTarget *renderTarget = new RenderTarget();
    Surface *colorBuffer = new Surface(kFbWidth, kFbHeight, frameBuffer);
    Surface *depthBuffer = new Surface(kFbWidth, kFbHeight);
    renderTarget->setColorBuffer(colorBuffer);
    renderTarget->setDepthBuffer(depthBuffer);
    context->bindTarget(renderTarget);
    context->enableDepthBuffer(true);
    context->bindShader(new TextureShader());

    const RenderBuffer kVertices(kCubeVertices, kNumCubeVertices, 5 * sizeof(float));
    const RenderBuffer kIndices(kCubeIndices, kNumCubeIndices, sizeof(int));
    context->bindVertexAttrs(&kVertices);

    Texture *texture = new Texture();
    texture->setMipSurface(0, new Surface(128, 128, (void*) kTestTexture));
    texture->enableBilinearFiltering(true);
    context->bindTexture(0, texture);

    Matrix projectionMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);
    Matrix modelViewMatrix;
    Matrix rotationMatrix;
    modelViewMatrix = Matrix::getTranslationMatrix(Vec3(0.0f, 0.0f, -3.0f));
    modelViewMatrix *= Matrix::getScaleMatrix(2.0f);
    modelViewMatrix *= Matrix::getRotationMatrix(M_PI / 3.5, Vec3(1, -1, 0));
    rotationMatrix = Matrix::getRotationMatrix(M_PI / 8, Vec3(1, 1, 0.0f));

    for (int frame = 0; frame < 1; frame++)
    {
        TextureUniforms uniforms;
        uniforms.fMVPMatrix = projectionMatrix * modelViewMatrix;
        context->bindUniforms(&uniforms, sizeof(uniforms));
        context->clearColorBuffer();
        context->drawElements(&kIndices);
        context->finish();
        modelViewMatrix *= rotationMatrix;
    }

    return 0;
}
