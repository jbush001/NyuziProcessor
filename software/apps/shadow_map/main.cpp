//
// Copyright 2017 Jeff Bush
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
// Render a torus with shadows computed on the fly. Demonstrates using
// render-to-texture with librender.
//

#include <math.h>
#include <Matrix.h>
#include <nyuzi.h>
#include <RenderContext.h>
#include <RenderTarget.h>
#include <schedule.h>
#include <stdlib.h>
#include <vga.h>
#include "ShadowMapShader.h"
#include "OutputShader.h"
#include "torus.h"

// Debug option to see scene from perspective of light
//#define SHOW_SHADOW_MAP 1

using namespace librender;

namespace
{
const int kLightmapSize = 256;
const float kGroundVertices[] =
{
    -1.0, -1.0, -1.0,
     1.0, -1.0, -1.0,
     1.0,  1.0, -1.0,
    -1.0,  1.0, -1.0
};
const int kNumGroundVertices = 4;
const int kGroundIndices[] = { 0, 1, 2, 2, 3, 0 };
const int kNumGroundIndices = 6;
} // namespace

// All threads start execution here.
int main()
{
    void *frameBuffer;
    if (get_current_thread_id() != 0)
        worker_thread();

    frameBuffer = init_vga(VGA_MODE_640x480);

    start_all_threads();

    RenderContext *context = new RenderContext();

    // Shadow map that is both a source texture and render target
    // XXX Ideally we would make this texture 16 bits with a single channel,
    // but librender currently hardcodes one surface format (RGBA8888),
    // which wastes some memory and limits the depth resolution to 256.
    // It would also be ideal to bind the texture as the depth buffer so
    // we didn't need a color buffer.
    Surface *lightMapSurface = new Surface(kLightmapSize, kLightmapSize);
    Surface *lightDepthBuffer = new Surface(kLightmapSize, kLightmapSize);
    RenderTarget *lightMapTarget = new RenderTarget();
    lightMapTarget->setColorBuffer(lightMapSurface);
    lightMapTarget->setDepthBuffer(lightDepthBuffer);
    Shader *lightMapShader = new ShadowMapShader();
    Texture *lightMapTexture = new Texture();
    lightMapTexture->enableBilinearFiltering(true);
    lightMapTexture->setMipSurface(0, lightMapSurface);

    // Output framebuffer target
    RenderTarget *outputTarget = new RenderTarget();
    Surface *colorBuffer = new Surface(FB_WIDTH, FB_HEIGHT, frameBuffer);
    Surface *depthBuffer = new Surface(FB_WIDTH, FB_HEIGHT);
    outputTarget->setColorBuffer(colorBuffer);
    outputTarget->setDepthBuffer(depthBuffer);
#if !SHOW_SHADOW_MAP
    Shader *outputShader = new OutputShader();
#endif

    ShadowMapUniforms lightMapUniforms;
    OutputUniforms outputUniforms;

    const RenderBuffer torusVertexBuffer(kTorusVertices, kNumTorusVertices,
        6 * sizeof(float));
    const RenderBuffer torusIndexBuffer(kTorusIndices, kNumTorusIndices,
        sizeof(int));
    const RenderBuffer groundVertexBuffer(kGroundVertices, kNumGroundVertices,
        3 * sizeof(float));
    const RenderBuffer groundIndexBuffer(kGroundIndices, kNumGroundIndices,
        sizeof(int));

    Matrix modelMatrix;
#if !SHOW_SHADOW_MAP
    Matrix projectionMatrix = Matrix::getProjectionMatrix(FB_WIDTH, FB_HEIGHT);
    Matrix viewMatrix = Matrix::lookAt(Vec3(-1.2, 1.4, 0.1), Vec3(0, 0, 0), Vec3(0, 0, 1));
#endif

    outputUniforms.fDirectional = 0.6f;
    outputUniforms.fAmbient = 0.2f;
    Matrix modelRotationMatrix = Matrix::getRotationMatrix(M_PI / 16, Vec3(0, 1, 0));
    Matrix viewRotationMatrix = Matrix::getRotationMatrix(M_PI / 20, Vec3(0, 0, 1));
    Matrix lightViewMatrix = Matrix::lookAt(Vec3(0, 0, 2),
        Vec3(0, 0, 0), Vec3(0, 1, 0));
    outputUniforms.fLightVector = lightViewMatrix.upper3x3() * Vec3(0, 0, -1);
    context->enableDepthBuffer(true);

    for (int frame = 0; ; frame++)
    {
        // Shadow map pass
#if SHOW_SHADOW_MAP
        context->bindTarget(outputTarget);
#else
        context->bindTarget(lightMapTarget);
#endif
        context->bindShader(lightMapShader);
        context->clearColorBuffer();

        lightMapUniforms.fMVPMatrix = lightViewMatrix;
        context->bindUniforms(&lightMapUniforms, sizeof(lightMapUniforms));
        context->bindVertexAttrs(&groundVertexBuffer);
        context->drawElements(&groundIndexBuffer);

        lightMapUniforms.fMVPMatrix = lightViewMatrix * modelMatrix;
        context->bindUniforms(&lightMapUniforms, sizeof(lightMapUniforms));
        context->bindVertexAttrs(&torusVertexBuffer);
        context->drawElements(&torusIndexBuffer);

        context->finish();

#if !SHOW_SHADOW_MAP
        // Output pass
        context->bindTexture(0, lightMapTexture);
        context->bindTarget(outputTarget);
        context->bindShader(outputShader);
        context->clearColorBuffer();

        outputUniforms.fLightMatrix = lightViewMatrix;
        outputUniforms.fMVPMatrix = projectionMatrix * viewMatrix;
        outputUniforms.fNormalMatrix = viewMatrix.upper3x3();
        context->bindUniforms(&outputUniforms, sizeof(outputUniforms));
        context->bindVertexAttrs(&groundVertexBuffer);
        context->drawElements(&groundIndexBuffer);

        Matrix modelViewMatrix = viewMatrix * modelMatrix;
        outputUniforms.fLightMatrix = lightViewMatrix * modelMatrix;
        outputUniforms.fMVPMatrix = projectionMatrix * modelViewMatrix;
        outputUniforms.fNormalMatrix = modelViewMatrix.upper3x3();
        context->bindUniforms(&outputUniforms, sizeof(outputUniforms));
        context->bindVertexAttrs(&torusVertexBuffer);
        context->drawElements(&torusIndexBuffer);

        context->finish();
#endif

        modelMatrix *= modelRotationMatrix;
        viewMatrix *= viewRotationMatrix;
    }

    return 0;
}
