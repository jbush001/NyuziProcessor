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

#pragma once

#include <RenderContext.h>
#include <Vec3.h>

struct RenderBspNode
{
    bool pointInFront(float x, float y, float z) const
    {
        return (x * normal[0] + y * normal[1] + z * normal[2] - distance) > 0;
    }

    float normal[3];
    float distance;
    RenderBspNode *frontChild = nullptr;
    RenderBspNode *backChild = nullptr;
    RenderBspNode *parent = nullptr;
    int pvsIndex;
    librender::RenderBuffer vertexBuffer;
    librender::RenderBuffer indexBuffer;
    int markNumber;
};

class LevelRenderer
{
public:
    void setBspData(RenderBspNode *root, const uint8_t *pvsList,
                    RenderBspNode *leaves, int numLeaves,
                    librender::Texture *atlasTexture, librender::Texture *lightmapAtlas);
    void render(librender::RenderContext *context, const librender::Vec3 &cameraPos);

private:
    RenderBspNode *fBspRoot;
    const uint8_t *fPvsList;
    RenderBspNode *fLeaves;
    int fNumLeaves;
    librender::Texture *fTextureAtlasTexture;
    librender::Texture *fLightmapAtlasTexture;
    int fFrame;
};
