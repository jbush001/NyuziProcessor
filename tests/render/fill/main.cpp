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
// Fill the entire framebuffer with a solid color.
// Validates rasterizer viewport clipping and all
// rasterizer coverage cases
//

#include <math.h>
#include <Matrix.h>
#include <nyuzi.h>
#include <RenderContext.h>
#include <RenderTarget.h>
#include <schedule.h>
#include <stdlib.h>
#include <vga.h>
#include "ColorShader.h"

// Ensure clipping works correctly by filling entire framebuffer

using namespace librender;

const int kFbWidth = 640;
const int kFbHeight = 480;

static float kSquareVertices[] =
{
    -1.1,  1.1, -1.0,
    -1.1, -1.1, -1.0,
    1.1, -1.1, -1.0,
    1.1,  1.1, -1.0,
};

static int kSquareIndices[] = { 0, 1, 2, 2, 3, 0 };

// All threads start execution here.
int main()
{
    void *frameBuffer;
    if (get_current_thread_id() != 0)
        worker_thread();

    // Set up render context
    frameBuffer = init_vga(VGA_MODE_640x480);

    start_all_threads();

    RenderContext *context = new RenderContext();
    RenderTarget *renderTarget = new RenderTarget();
    Surface *colorBuffer = new Surface(kFbWidth, kFbHeight, frameBuffer);
    renderTarget->setColorBuffer(colorBuffer);
    context->bindTarget(renderTarget);
    context->bindShader(new ColorShader());

    const RenderBuffer kVertices(kSquareVertices, 4, 3 * sizeof(float));
    const RenderBuffer kIndices(kSquareIndices, 6, sizeof(int));
    context->bindVertexAttrs(&kVertices);
    context->drawElements(&kIndices);
    context->finish();
    return 0;
}
