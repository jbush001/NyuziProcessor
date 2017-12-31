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


#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <math.h>
#include "PakFile.h"
#include "MeshBuilder.h"

using namespace librender;

bool PakFile::open(const char *filename)
{
    if (fFile)
        fclose(fFile);

    fFile = fopen(filename, "rb");

    pakheader_t header;
    if (fread(&header, sizeof(header), 1, fFile) != 1)
    {
        printf("PakFile::open: error reading file\n");
        return false;
    }

    if (::memcmp(header.id, "PACK", 4) != 0)
    {
        printf("PakFile::open: bad file type\n");
        return false;
    }

    fNumDirEntries = header.dirSize / sizeof(pakfile_t);
    fDirectory = new pakfile_t[fNumDirEntries];
    fseek(fFile, header.dirOffset, SEEK_SET);
    if (fread(fDirectory, header.dirSize, 1, fFile) != 1)
    {
        printf("PakFile::open: error reading directory\n");
        return false;
    }

    return true;
}

// Read a file archived in the PAK file into memory and return
// a pointer to the allocated buffer.
void *PakFile::readFile(const char *lumpname) const
{
    int fileIndex;

    for (fileIndex = 0; fileIndex < fNumDirEntries; fileIndex++)
    {
        if (::strcmp(fDirectory[fileIndex].name, lumpname) == 0)
            break;
    }

    if (fileIndex == fNumDirEntries)
        return nullptr;

    void *buf = malloc(fDirectory[fileIndex].size);
    fseek(fFile, fDirectory[fileIndex].offset, SEEK_SET);

    if (fread(buf, fDirectory[fileIndex].size, 1, fFile) != 1)
    {
        printf("PakFile::readFile: error reading\n");
        free(buf);
        return nullptr;
    }

    return buf;
}

void PakFile::dumpDirectory() const
{
    for (int i = 0; i < fNumDirEntries; i++)
    {
        printf("   %s %08x %08x\n", fDirectory[i].name, fDirectory[i].offset,
               fDirectory[i].size);
    }
}

Entity *PakFile::findEntityByClassName(const char *className)
{
    for (Entity *ent = fEntityList; ent; ent = ent->next)
    {
        for (EntityAttribute *attr = ent->attributeList; attr; attr = attr->next)
        {
            if (strcmp(attr->name, "classname") == 0)
            {
                if (strcmp(attr->value, className) == 0)
                    return ent;

                break;
            }
        }
    }

    return nullptr;
}

void PakFile::dumpEntities() const
{
    for (Entity *ent = fEntityList; ent; ent = ent->next)
    {
        printf("{\n");
        for (EntityAttribute *attr = ent->attributeList; attr; attr = attr->next)
            printf(" %s: %s\n", attr->name, attr->value);

        printf("}\n");
    }
}

void PakFile::readBspFile(const char *bspFilename)
{
    uint8_t *data = (uint8_t*) readFile(bspFilename);
    if (data == nullptr)
    {
        printf("Couldn't find BSP file");
        return;
    }

    const bspheader_t *bspHeader = reinterpret_cast<bspheader_t*>(data);

    if (bspHeader->version != kBspVersion)
    {
        printf("bad BSP version\n");
        exit(1);
    }

    loadTextureAtlas(bspHeader, data);
    loadLightmaps(bspHeader, data);
    loadBspNodes(bspHeader, data);

    int pvsLen = bspHeader->visibility.length;
    fPvsData = (unsigned char*) malloc(pvsLen);
    ::memcpy(fPvsData, data + bspHeader->visibility.offset, pvsLen);

    printf("%d BSP nodes\n", fNumBspLeaves + fNumInteriorNodes);

    parseEntities((const char*)(data + bspHeader->entities.offset));

    ::free(data);
}

const int kAtlasSize = 1024;

// This is the guart margin at the largest mip level. At every level it is divided by two.
// It's two pixels at the lowest mip level.
const int kGuardMargin = 16;

struct TexturePackingData
{
    int textureId;
    unsigned int width;
    unsigned int height;
    const uint8_t *data[kNumMipLevels];
};

namespace
{

int compareTexturePackingData(const void *a, const void *b)
{
    return reinterpret_cast<const TexturePackingData*>(b)->height
        - reinterpret_cast<const TexturePackingData*>(a)->height;
}

}

void PakFile::loadTextureAtlas(const bspheader_t *bspHeader, const uint8_t *data)
{
    //
    // Read the palette.  Expand from 24bpp to 32bpp, our native format.
    //
    uint8_t *rawPalette = (uint8_t*) readFile("gfx/palette.lmp");
    uint32_t *palette = new uint32_t[256];
    for (int i = 0; i < 256; i++)
    {
        // Palette is R, G, B
        palette[i] = (rawPalette[i * 3 + 2] << 16) | (rawPalette[i * 3 + 1] << 8)
                     | rawPalette[i * 3];
    }

    ::free(rawPalette);

    //
    // Copy texture information into a temporary array
    //
    const miptex_lump_t *mipHeader = reinterpret_cast<const miptex_lump_t*>(data
        + bspHeader->textures.offset);
    fNumTextures = mipHeader->numTextures;
    printf("%d textures\n", mipHeader->numTextures);

    TexturePackingData *texArray = new TexturePackingData[mipHeader->numTextures];
    for (int textureIdx = 0; textureIdx < mipHeader->numTextures; textureIdx++)
    {
        texArray[textureIdx].textureId = textureIdx;
        if (mipHeader->offset[textureIdx] == -1)
        {
            // Not clear why this exists, but code in quake/client/model.c, Mod_LoadTexture
            // (line 360) skips entries if the offset is -1
            for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
                texArray[textureIdx].data[mipLevel] = nullptr;

            texArray[textureIdx].width = 0;
            texArray[textureIdx].height = 0;
            continue;
        }

        const miptex_t *texture = reinterpret_cast<const miptex_t*>(data + bspHeader->textures.offset
                                  + mipHeader->offset[textureIdx]);
        texArray[textureIdx].width = texture->width;
        texArray[textureIdx].height = texture->height;
        for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
        {
            texArray[textureIdx].data[mipLevel] = data + bspHeader->textures.offset
                                                  + mipHeader->offset[textureIdx] + texture->offsets[mipLevel];
        }
    }

    //
    // Sort textures by vertical size to pack better
    //
    qsort(texArray, mipHeader->numTextures, sizeof(TexturePackingData),
          compareTexturePackingData);

    //
    // Create atlas mip surfaces
    //
    Surface *atlasSurfaces[kNumMipLevels]; // One for each mip level
    for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
    {
        atlasSurfaces[mipLevel] = new Surface(kAtlasSize >> mipLevel, kAtlasSize >> mipLevel,
            Surface::RGBA8888);
        ::memset(atlasSurfaces[mipLevel]->bits(), 0, (kAtlasSize >> mipLevel) * (kAtlasSize >> mipLevel)
                 * 4);
    }

    //
    // [Lightly] pack textures into the atlas. Horizontal bands are fixed height.
    //
    fTextureAtlasEntries = new AtlasEntry[mipHeader->numTextures];
    int destX = kGuardMargin;
    int destY = kGuardMargin;
    int destRowHeight = texArray[0].height;
    for (int textureIdx = 0; textureIdx < mipHeader->numTextures; textureIdx++)
    {
        if (texArray[textureIdx].data[0] == nullptr)
            continue;    // Skip unused texture entries

        if (destX + texArray[textureIdx].width + kGuardMargin > kAtlasSize)
        {
            // Start a new band
            destX = kGuardMargin;
            destY += destRowHeight + kGuardMargin;
            destRowHeight = texArray[textureIdx].height;
            assert(destY + destRowHeight <= kAtlasSize);
        }

        // Save the coordinates of this texture in the atlas.
        int textureId = texArray[textureIdx].textureId;
        fTextureAtlasEntries[textureId].left = float(destX) / (kAtlasSize - 1);
        fTextureAtlasEntries[textureId].bottom = 1.0 - (float(destY + texArray[textureIdx].height - 1) / (kAtlasSize - 1));
        fTextureAtlasEntries[textureId].width = float(texArray[textureIdx].width) / (kAtlasSize - 1);
        fTextureAtlasEntries[textureId].height = float(texArray[textureIdx].height) / (kAtlasSize - 1);
        fTextureAtlasEntries[textureId].pixelWidth = texArray[textureIdx].width;
        fTextureAtlasEntries[textureId].pixelHeight = texArray[textureIdx].height;

        for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
        {
            int destStride = kAtlasSize >> mipLevel;
            int srcMipWidth = texArray[textureIdx].width >> mipLevel;
            int srcMipHeight = texArray[textureIdx].height >> mipLevel;
            assert(srcMipHeight <= destRowHeight);

            // Copy the data into the atlas
            uint32_t *dest = static_cast<uint32_t*>(atlasSurfaces[mipLevel]->bits())
                             + ((destY >> mipLevel) * destStride + (destX >> mipLevel));
            const uint8_t *src = static_cast<const uint8_t*>(texArray[textureIdx].data[mipLevel]);
            if (src == nullptr)
                continue;    // Skip unused texture

#define dest_pixel(x, y) dest[(y) * destStride + (x)]
#define src_pixel(x, y) palette[src[(y) * srcMipWidth + (x)]]

            // Expand palette and copy into atlas surface
            for (int y = 0; y < srcMipHeight; y++)
            {
                for (int x = 0; x < srcMipWidth; x++)
                    dest_pixel(x, y) = src_pixel(x, y);

                // Mirror one pixel outside the right edge to the left and vice versa
                // to wrap properly with bilinear filtering. This is outside the bounds
                // for the texture, but in the guard region that was reserved for this
                // purpose.
                dest_pixel(-1, y) = src_pixel(srcMipWidth, y);
                dest_pixel(srcMipWidth, y) = src_pixel(-1, y);
            }

            // Mirror top edge to bottom, etc. as above.
            for (int x = 0; x < srcMipWidth; x++)
            {
                dest_pixel(x, -1) = src_pixel(x, srcMipHeight);
                dest_pixel(x, srcMipHeight) = src_pixel(x, -1);
            }

            // Fill in four corners on the outside edge
            dest_pixel(-1, -1) = src_pixel(0, 0);
            dest_pixel(srcMipWidth, -1) = src_pixel(srcMipWidth - 1, 0);
            dest_pixel(-1, srcMipHeight) = src_pixel(0, srcMipHeight - 1);
            dest_pixel(srcMipWidth, srcMipHeight) = src_pixel(srcMipWidth - 1, srcMipHeight - 1);

#undef src_pixel
#undef dest_pixel
        }

        destX += texArray[textureIdx].width + kGuardMargin;
    }

    delete[] palette;

    fTextureAtlasTexture = new Texture();
    fTextureAtlasTexture->enableBilinearFiltering(true);
    for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
        fTextureAtlasTexture->setMipSurface(mipLevel, atlasSurfaces[mipLevel]);

    delete[] texArray;
}

const int kLightmapGuard = 2;
const int kLightmapSize = 1024;

void PakFile::loadLightmaps(const bspheader_t *bspHeader, const uint8_t *data)
{
    const face_t *faces = reinterpret_cast<const face_t*>(data
        + bspHeader->faces.offset);
    int numFaces = bspHeader->faces.length / sizeof(face_t);
    const int32_t *edgeList = reinterpret_cast<const int32_t*>(data
        + bspHeader->surfedges.offset);
    const edge_t *edges = reinterpret_cast<const edge_t*>(data
        + bspHeader->edges.offset);
    const texture_info_t *texInfos = reinterpret_cast<const texture_info_t*>(data
        + bspHeader->texinfo.offset);
    const vertex_t *vertices = reinterpret_cast<const vertex_t*>(data
        + bspHeader->vertices.offset);
    const uint8_t *lightmaps = reinterpret_cast<const uint8_t*>(data
        + bspHeader->lighting.offset);

    fLightmapAtlasEntries = new AtlasEntry[numFaces];

    Surface *lightmapSurface = new Surface(kLightmapSize, kLightmapSize, Surface::GRAY8);
    memset(lightmapSurface->bits(), 0, kLightmapSize * kLightmapSize);
    uint8_t *destPtr = (uint8_t*) lightmapSurface->bits();

    // Put a dummy map in the upper left corner for faces that don't have a
    // lightmap (they are black)
    int lightmapX = 6;
    int lightmapY = 1;
    int bandHeight = 4;

    for (int faceIndex = 0; faceIndex < numFaces; faceIndex++)
    {
        // What is the size of this face?
        float uMax = -10000;
        float uMin = 10000;
        float vMax = -10000;
        float vMin = 10000;

        const face_t &face = faces[faceIndex];
        const texture_info_t &textureInfo = texInfos[face.texture];
        for (int edgeListIndex = face.firstEdge;
                edgeListIndex < face.firstEdge + face.numEdges;
                edgeListIndex++)
        {
            int16_t edgeIndex = edgeList[edgeListIndex];
            int vertexIndex;
            if (edgeIndex < 0)
            {
                // Reverse direction
                vertexIndex = edges[-edgeIndex].endVertex;
            }
            else
                vertexIndex = edges[edgeIndex].startVertex;

            // Compute texture coordinates
            vertex_t vertex = vertices[vertexIndex];
            float u = vertex.coord[0] * textureInfo.uVector[0]
                      + vertex.coord[1] * textureInfo.uVector[1]
                      + vertex.coord[2] * textureInfo.uVector[2]
                      + textureInfo.uVector[3];
            float v = vertex.coord[0] * textureInfo.vVector[0]
                      + vertex.coord[1] * textureInfo.vVector[1]
                      + vertex.coord[2] * textureInfo.vVector[2]
                      + textureInfo.vVector[3];

            if (u > uMax)
                uMax = u;

            if (v > vMax)
                vMax = v;

            if (u < uMin)
                uMin = u;

            if (v < vMin)
                vMin = v;
        }

        int lightmapPixelWidth = int(ceilf(uMax) - floorf(uMin)) / 16 + 1;
        int lightmapPixelHeight = int(ceilf(vMax) - floorf(vMin)) / 16 + 1;


        AtlasEntry &atlasEnt = fLightmapAtlasEntries[faceIndex];
        if (face.lightOffset < 0)
            continue;    // No map

        atlasEnt.left = float(lightmapX) / (kLightmapSize - 1);
        atlasEnt.bottom = 1.0 - (float(lightmapY + lightmapPixelHeight - 1) / (kLightmapSize - 1));
        atlasEnt.width = float(lightmapPixelWidth - 1) / (kLightmapSize - 1);
        atlasEnt.height = float(lightmapPixelHeight - 1) / (kLightmapSize - 1);
        atlasEnt.pixelWidth = lightmapPixelWidth;
        atlasEnt.pixelHeight = lightmapPixelHeight;
        atlasEnt.uOffset = uMin;
        atlasEnt.vOffset = vMin;

        // Copy into lightmap
        const uint8_t *lightmapSrc = lightmaps + face.lightOffset;
        for (int y = 0; y < lightmapPixelHeight; y++)
        {
            for (int x = 0; x < lightmapPixelWidth; x++)
            {
                destPtr[(lightmapY + y) * kLightmapSize + lightmapX + x]
                    = *lightmapSrc++;;
            }
        }

        if (lightmapPixelHeight > bandHeight)
            bandHeight = lightmapPixelHeight;

        lightmapX += lightmapPixelWidth + kLightmapGuard;
        if (lightmapX > kLightmapSize)
        {
            // Next band
            lightmapX = 1;
            lightmapY += bandHeight + kLightmapGuard;
            if (lightmapY > kLightmapSize)
            {
                printf("error:lightmap doesn't fit\n");
                abort();
            }

            bandHeight = 0;
        }
    }

    fLightmapAtlasTexture = new Texture();
    fLightmapAtlasTexture->enableBilinearFiltering(true);
    fLightmapAtlasTexture->setMipSurface(0, lightmapSurface);
}

void PakFile::loadBspNodes(const bspheader_t *bspHeader, const uint8_t *data)
{
    const leaf_t *leaves = reinterpret_cast<const leaf_t*>(data + bspHeader->leaves.offset);
    const uint16_t *faceList = reinterpret_cast<const uint16_t*>(data
        + bspHeader->marksurfaces.offset);
    const face_t *faces = reinterpret_cast<const face_t*>(data
        + bspHeader->faces.offset);
    const int32_t *edgeList = reinterpret_cast<const int32_t*>(data
        + bspHeader->surfedges.offset);
    const edge_t *edges = reinterpret_cast<const edge_t*>(data
        + bspHeader->edges.offset);
    const vertex_t *vertices = reinterpret_cast<const vertex_t*>(data
        + bspHeader->vertices.offset);
    const texture_info_t *texInfos = reinterpret_cast<const texture_info_t*>(data
        + bspHeader->texinfo.offset);
    const bspnode_t *nodes = reinterpret_cast<const bspnode_t*>(data
        + bspHeader->nodes.offset);
    const plane_t *planes = reinterpret_cast<const plane_t*>(data
        + bspHeader->planes.offset);

    fNumBspLeaves = bspHeader->leaves.length / sizeof(leaf_t);
    fNumInteriorNodes = bspHeader->nodes.length / sizeof(bspnode_t);
    fBspNodes = new RenderBspNode[fNumInteriorNodes + fNumBspLeaves];

    // Initialize leaf nodes
    for (int leafIndex = 0; leafIndex < fNumBspLeaves; leafIndex++)
    {
        MeshBuilder builder(11);

        const leaf_t &leaf = leaves[leafIndex];
        for (int faceListIndex = leaf.firstMarkSurface;
                faceListIndex < leaf.firstMarkSurface + leaf.numMarkSurfaces;
                faceListIndex++)
        {
            int faceIndex = faceList[faceListIndex];
            const face_t &face = faces[faceIndex];
            const texture_info_t &textureInfo = texInfos[face.texture];
            float left = fTextureAtlasEntries[textureInfo.miptex].left;
            float bottom = fTextureAtlasEntries[textureInfo.miptex].bottom;
            float width = fTextureAtlasEntries[textureInfo.miptex].width;
            float height = fTextureAtlasEntries[textureInfo.miptex].height;

            float polyAttrs[11] = { 0, 0, 0, left, bottom, width, height, 0, 0, 0, 0 };

            for (int edgeListIndex = face.firstEdge;
                    edgeListIndex < face.firstEdge + face.numEdges;
                    edgeListIndex++)
            {
                int16_t edgeIndex = edgeList[edgeListIndex];
                int vertexIndex;
                if (edgeIndex < 0)
                {
                    // Reverse direction
                    vertexIndex = edges[-edgeIndex].endVertex;
                }
                else
                {
                    vertexIndex = edges[edgeIndex].startVertex;
                }

                // Copy coordinate
                for (int i = 0; i < 3; i++)
                    polyAttrs[i] = vertices[vertexIndex].coord[i];

                // u and v are texture coordinates, in pixels
                float u = (polyAttrs[0] * textureInfo.uVector[0]
                           + polyAttrs[1] * textureInfo.uVector[1]
                           + polyAttrs[2] * textureInfo.uVector[2]
                           + textureInfo.uVector[3]);
                float v = polyAttrs[0] * textureInfo.vVector[0]
                          + polyAttrs[1] * textureInfo.vVector[1]
                          + polyAttrs[2] * textureInfo.vVector[2]
                          + textureInfo.vVector[3];

                // Compute texture coordinates
                polyAttrs[7] = u / fTextureAtlasEntries[textureInfo.miptex].pixelWidth;
                polyAttrs[8] = -v / fTextureAtlasEntries[textureInfo.miptex].pixelHeight;

                // Set lightmap coordinates
                if (face.lightOffset < 0)
                {
                    // No lightmap, point to dummy (full dark) lightmap.
                    polyAttrs[9] = float(1.0) / (kLightmapSize - 1);
                    polyAttrs[10] = 1.0 - (float(1.0) / (kLightmapSize - 1));
                }
                else
                {
                    AtlasEntry &lightmapEnt = fLightmapAtlasEntries[faceIndex];
                    polyAttrs[9] = lightmapEnt.left + (u - lightmapEnt.uOffset) / 16 / lightmapEnt.pixelWidth * lightmapEnt.width;
                    polyAttrs[10] = lightmapEnt.bottom + (1.0 - ((v - lightmapEnt.vOffset) / 16 / lightmapEnt.pixelHeight)) * lightmapEnt.height;
                }

                builder.addPolyPoint(polyAttrs);
            }

            builder.finishPoly();
        }

        builder.finish(fBspNodes[fNumInteriorNodes + leafIndex].vertexBuffer,
                       fBspNodes[fNumInteriorNodes + leafIndex].indexBuffer);
        fBspNodes[fNumInteriorNodes + leafIndex].pvsIndex = leaves[leafIndex].pvsOffset;
    }

    //
    // Initialize interior nodes
    //
    for (int i = 0; i < fNumInteriorNodes; i++)
    {
        const plane_t &nodePlane = planes[nodes[i].plane];
        for (int j = 0; j < 3; j++)
            fBspNodes[i].normal[j] = nodePlane.normal[j];

        fBspNodes[i].distance = nodePlane.distance;

        if (nodes[i].children[0] & 0x8000)
            fBspNodes[i].frontChild = &fBspNodes[~nodes[i].children[0] + fNumInteriorNodes];
        else
            fBspNodes[i].frontChild = &fBspNodes[nodes[i].children[0]];

        if (nodes[i].children[1] & 0x8000)
            fBspNodes[i].backChild = &fBspNodes[~nodes[i].children[1] + fNumInteriorNodes];
        else
            fBspNodes[i].backChild = &fBspNodes[nodes[i].children[1]];

        fBspNodes[i].frontChild->parent = &fBspNodes[i];
        fBspNodes[i].backChild->parent = &fBspNodes[i];
    }
}

// {
// "classname" "info_player_coop"
// "origin" "-824 -1584 88"
// "angle" "270"
// }

namespace
{

char *dupStr(const char *start, int length)
{
    char *ptr = (char*) malloc(length + 1);
    memcpy(ptr, start, length);
    ptr[length] = '\0';

    return ptr;
}

}

void PakFile::parseEntities(const char *data)
{
    bool inQuote = false;
    bool inName = true;
    Entity *entity;
    EntityAttribute *attr;
    const char *quoteStart;

    for (const char *c = data; *c; c++)
    {
        if (inQuote)
        {
            if (*c == '"')
            {
                // End of a quoted string
                const char *mallocStr = dupStr(quoteStart, c - quoteStart);
                if (inName)
                {
                    attr = new EntityAttribute;
                    attr->next = entity->attributeList;
                    entity->attributeList = attr;
                    attr->name = mallocStr;
                    inName = false;
                }
                else
                {
                    attr->value = mallocStr;
                    inName = true;
                }

                inQuote = false;
            }
        }
        else if (*c == '"')
        {
            if (!entity)
            {
                printf("error parsing entities, unexpected \"\n");
                return;
            }

            quoteStart = c + 1;
            inQuote = true;
        }
        else if (*c == '{')
        {
            if (inName == 0)
            {
                printf("missing value\n");
                return;
            }

            entity = new Entity;
            entity->next = fEntityList;
            fEntityList = entity;
        }
        else if (*c == '}')
            entity = nullptr;
    }
}
