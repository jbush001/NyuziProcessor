//
// Copyright 2015 Jeff Bush
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

#include <ctype.h>
#include <keyboard.h>
#include <nyuzi.h>
#include <RenderContext.h>
#include <schedule.h>
#include <SIMDMath.h>
#include <stdio.h>
#include <Surface.h>
#include <time.h>
#include <vga.h>
#include "PakFile.h"
#include "Render.h"
#include "TextureShader.h"

using namespace librender;

enum Button
{
    kUpArrow,
    kDownArrow,
    kRightArrow,
    kLeftArrow,
    kUKey,
    kDKey
};

namespace
{

const Vec3 kUpVector(0, 0, 1);
Vec3 gCameraPos;
Matrix gCameraOrientationMatrix;
Matrix kRotateLeft = Matrix::getRotationMatrix(-M_PI / 8, kUpVector);
Matrix kRotateRight = Matrix::getRotationMatrix(M_PI / 8, kUpVector);
const float kMoveSpeed = 20.0;

bool gKeyPressed[6] = { false, false, false, false, false, false };
bool gWireframeRendering = false;
bool gBilinearFiltering = true;
bool gEnableLightmap = true;
bool gEnableTexture = true;

void processKeyboardEvents()
{
    // Consume as many keyboard events as are available.
    while (true)
    {
        unsigned int keyCode = poll_keyboard();
        if (keyCode == 0xffffffff)
            break;

        bool pressed = (keyCode & KBD_PRESSED) ? true : false;
        switch (keyCode & 0xff)
        {
            case KBD_RIGHTARROW:
                gKeyPressed[kRightArrow] = pressed;
                break;
            case KBD_LEFTARROW:
                gKeyPressed[kLeftArrow] = pressed;
                break;

            case KBD_UPARROW:
                gKeyPressed[kUpArrow] = pressed;
                break;

            case KBD_DOWNARROW:
                gKeyPressed[kDownArrow] = pressed;
                break;

            case 'u':
                gKeyPressed[kUKey] = pressed;
                break;

            case 'd':
                gKeyPressed[kDKey] = pressed;
                break;

            // Toggle gWireframeRendering
            case 'w':
                if (keyCode & KBD_PRESSED)
                    gWireframeRendering = !gWireframeRendering;

                break;

            // Toggle lightmap
            case 'l':
                if (keyCode & KBD_PRESSED)
                {
                    // Toggle through three modes: texture + lightmap, texture only,
                    // lightmap only
                    if (gEnableLightmap)
                    {
                        if (gEnableTexture)
                            gEnableLightmap = false;
                        else
                            gEnableTexture = true;
                    }
                    else
                    {
                        gEnableLightmap = true;
                        gEnableTexture = false;
                    }
                }

                break;

            // Toggle bilinear filtering
            case 'b':
                if (keyCode & KBD_PRESSED)
                    gBilinearFiltering = !gBilinearFiltering;

                break;

        }
    }
    // Handle movement
    if (gKeyPressed[kRightArrow])
        gCameraOrientationMatrix *= kRotateRight;
    else if (gKeyPressed[kLeftArrow])
        gCameraOrientationMatrix *= kRotateLeft;

    if (gKeyPressed[kUpArrow])
        gCameraPos += gCameraOrientationMatrix.inverse() * Vec3(0, 0, -kMoveSpeed);
    else if (gKeyPressed[kDownArrow])
        gCameraPos += gCameraOrientationMatrix.inverse() * Vec3(0, 0, kMoveSpeed);

    if (gKeyPressed[kUKey])
        gCameraPos += gCameraOrientationMatrix.inverse() * Vec3(0, kMoveSpeed, 0);
    else if (gKeyPressed[kDKey])
        gCameraPos += gCameraOrientationMatrix.inverse() * Vec3(0, -kMoveSpeed, 0);
}

void parseCoordinateString(const char *string, float outCoord[3])
{
    const char *c = string;

    for (int coordIndex = 0; coordIndex < 3 && *c; coordIndex++)
    {
        while (*c && !isdigit(*c) && *c != '-')
            c++;

        bool isNegative = false;
        if (*c == '-')
        {
            isNegative = true;
            c++;
        }

        int value = 0;
        while (*c && isdigit(*c))
        {
            value = value * 10 + *c - '0';
            c++;
        }

        if (isNegative)
            value = -value;

        outCoord[coordIndex] = value;
    }
}

}



// All threads start execution here.
int main()
{
    void *frameBuffer;
    if (get_current_thread_id() != 0)
        worker_thread();

    // Set up render context
    frameBuffer = init_vga(VGA_MODE_640x480);
    RenderContext *context = new RenderContext(0x1000000);
    RenderTarget *renderTarget = new RenderTarget();
    Surface *colorBuffer = new Surface(FB_WIDTH, FB_HEIGHT, (void*) frameBuffer);
    Surface *zBuffer = new Surface(FB_WIDTH, FB_HEIGHT);
    renderTarget->setColorBuffer(colorBuffer);
    renderTarget->setDepthBuffer(zBuffer);
    context->bindTarget(renderTarget);
    context->enableDepthBuffer(true);
    context->bindShader(new TextureShader());

    // Read resources
    PakFile pak;
    pak.open("pak0.pak");
    pak.readBspFile("maps/e1m1.bsp");
    Texture *atlasTexture = pak.getTextureAtlasTexture();
    setBspData(pak.getBspTree(), pak.getPvsList(), pak.getBspTree() + pak.getNumInteriorNodes(),
               pak.getNumLeaves(), atlasTexture, pak.getLightmapAtlasTexture());
    Entity *ent = pak.findEntityByClassName("info_player_start");
    if (!ent)
    {
        printf("Error, couldn't find start position\n");
        return 1;
    }

    float facingAngle = float(atoi(ent->getAttribute("angle"))) / 360.0 * M_PI * 2;
    gCameraOrientationMatrix = Matrix::lookAt(Vec3(0, 0, 0), Vec3(cos(facingAngle),
                               sin(facingAngle), 0), kUpVector);

    float coords[3];
    parseCoordinateString(ent->getAttribute("origin"), coords);
    for (int i = 0; i < 3; i++)
        gCameraPos[i] = coords[i];

    printf("position %g %g %g angle %g\n", coords[0], coords[1], coords[2], facingAngle);

    // Start worker threads
    start_all_threads();

    TextureUniforms uniforms;
    Matrix projectionMatrix = Matrix::getProjectionMatrix(FB_WIDTH, FB_HEIGHT);

    for (int frame = 0; ; frame++)
    {
        processKeyboardEvents();

        context->enableWireframeMode(gWireframeRendering);
        atlasTexture->enableBilinearFiltering(gBilinearFiltering);

        // Set up uniforms
        Matrix viewMatrix = gCameraOrientationMatrix * Matrix::getTranslationMatrix(-gCameraPos);
        uniforms.fMVPMatrix = projectionMatrix * viewMatrix;
        uniforms.enableLightmap = gEnableLightmap;
        uniforms.enableTexture = gEnableTexture;

        context->bindUniforms(&uniforms, sizeof(uniforms));

        renderScene(context, gCameraPos);

        clock_t startTime = clock();
        context->finish();
        printf("rendered frame in %d uS\n", clock() - startTime);
    }
}
