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

//
// Code for reading and interpreting data in the .PAK file and its
// subfiles.
//

#pragma once

#include <RenderBuffer.h>
#include <stdio.h>
#include <string.h>
#include <Texture.h>
#include "pak.h"
#include "LevelRenderer.h"

struct EntityAttribute
{
    const char *name;
    const char *value;
    EntityAttribute *next;
};

struct Entity
{
    const char *getAttribute(const char *name)
    {
        for (EntityAttribute *attr = attributeList; attr; attr = attr->next)
            if (strcmp(attr->name, name) == 0)
                return attr->value;

        return nullptr;
    }

    EntityAttribute *attributeList = nullptr;
    Entity *next;
};

class PakFile
{
public:
    bool open(const char *filename);
    void readBspFile(const char *lumpname);
    librender::Texture *getTextureAtlasTexture()
    {
        return fTextureAtlasTexture;
    }

    librender::Texture *getLightmapAtlasTexture()
    {
        return fLightmapAtlasTexture;
    }

    void dumpDirectory() const;

    RenderBspNode *getBspTree()
    {
        return fBspNodes;	// First node is root
    }

    const uint8_t *getPvsList()
    {
        return fPvsData;
    }

    int getNumInteriorNodes() const
    {
        return fNumInteriorNodes;
    }

    int getNumLeaves() const
    {
        return fNumBspLeaves;
    }

    Entity *findEntityByClassName(const char *className);
    void dumpEntities() const;

private:
    struct AtlasEntry
    {
        float left;
        float bottom;
        float width;
        float height;
        int pixelWidth;
        int pixelHeight;
        float uOffset;
        float vOffset;
    };

    void *readFile(const char *filename) const;
    void loadTextureAtlas(const bspheader_t *bspHeader, const uint8_t *data);
    void loadLightmaps(const bspheader_t *bspHeader, const uint8_t *data);
    void loadBspNodes(const bspheader_t *bspHeader, const uint8_t *data);
    void parseEntities(const char *data);

    pakfile_t *fDirectory = nullptr;
    int fNumDirEntries;
    librender::Texture *fTextureAtlasTexture = nullptr;
    librender::Texture *fLightmapAtlasTexture = nullptr;
    AtlasEntry *fTextureAtlasEntries = nullptr;
    AtlasEntry *fLightmapAtlasEntries = nullptr;
    int fNumBspLeaves;
    int fNumTextures;
    FILE *fFile = nullptr;
    RenderBspNode *fBspNodes = nullptr;
    uint8_t *fPvsData = nullptr;
    int fNumInteriorNodes;
    Entity *fEntityList = nullptr;
};

