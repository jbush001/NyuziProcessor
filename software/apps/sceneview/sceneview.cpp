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

#include <nyuzi.h>
#include <RenderContext.h>
#include <schedule.h>
#include <stdio.h>
#include <Surface.h>
#include <time.h>
#include <vga.h>
#include "DepthShader.h"
#include "schedule.h"
#include "TextureShader.h"

//#define TEST_TEXTURE 1
//#define SHOW_DEPTH 1

namespace
{

struct FileHeader
{
    uint32_t fileSize;
    uint32_t numTextures;
    uint32_t numMeshes;
};

struct TextureEntry
{
    uint32_t offset;
    uint32_t mipLevels;
    uint16_t width;
    uint16_t height;
};

struct MeshEntry
{
    uint32_t offset;
    uint32_t textureId;
    uint32_t numVertices;
    uint32_t numIndices;
};

const int kAttrsPerVertex = 8;

char *readResourceFile()
{
    FileHeader header;
    char *resourceData;
    FILE *fp;

    fp = fopen("resource.bin", "rb");
    if (fp == nullptr)
    {
        printf("can't find resource.bin\n");
        return nullptr;
    }

    // Read the first block to determine how large the rest of the file is.
    if (fread(&header, sizeof(header), 1, fp) != 1)
    {
        printf("error reading resource file header\n");
        return nullptr;
    }

    printf("reading resource file, %d bytes\n", header.fileSize);

    resourceData = (char*) malloc(header.fileSize);
    fseek(fp, 0, SEEK_SET);
    if (fread(resourceData, header.fileSize, 1, fp) != 1)
    {
        printf("error reading resource file\n");
        return nullptr;
    }

    fclose(fp);

    return resourceData;
}

#if TEST_TEXTURE

// Test texture
const int kTestTextureSize = 128;
const int kCheckerSize = 32;

Texture *createCheckerboardTexture()
{
    const uint32_t kColors[] = {
        0x00ff0000,
        0x0000ff00,
        0x000000ff,
        0x00ff00ff,
    };

    Texture *texture = new Texture;
    for (int mipLevel = 0; mipLevel < 4; mipLevel++)
    {
        int mipSize = kTestTextureSize >> mipLevel;
        int subCheckerSize = kCheckerSize >> mipLevel;
        uint32_t checkerColor = kColors[mipLevel];
        Surface *surface = new Surface(mipSize, mipSize);
        uint32_t *bits = (uint32_t*) surface->bits();
        for (int x = 0; x < mipSize; x++)
        {
            for (int y = 0; y < mipSize; y++)
            {
                if (((x / subCheckerSize) & 1) ^ ((y / subCheckerSize) & 1))
                    bits[y * mipSize + x] = checkerColor;
                else
                    bits[y * mipSize + x] = 0xffffffff;
            }
        }

        texture->setMipSurface(mipLevel, surface);
    }

    return texture;
}

#endif

}

// All threads start execution here.
int main()
{
    void *frameBuffer;
    if (get_current_thread_id() != 0)
        worker_thread();

    // Set up render context
    frameBuffer = init_vga(VGA_MODE_640x480);

    // Set up resource data
    char *resourceData = readResourceFile();
    const FileHeader *resourceHeader = (FileHeader*) resourceData;
    const TextureEntry *texHeader = (TextureEntry*)(resourceData + sizeof(FileHeader));
    const MeshEntry *meshHeader = (MeshEntry*)(resourceData + sizeof(FileHeader) + resourceHeader->numTextures
                                  * sizeof(TextureEntry));
    Texture **textures = new Texture*[resourceHeader->numTextures];

    printf("%d textures %d meshes\n", resourceHeader->numTextures, resourceHeader->numMeshes);

    // Create texture objects
    for (unsigned int textureIndex = 0; textureIndex < resourceHeader->numTextures; textureIndex++)
    {
#if TEST_TEXTURE
        textures[textureIndex] = createCheckerboardTexture();
#else
        textures[textureIndex] = new Texture();
        textures[textureIndex]->enableBilinearFiltering(true);
        int offset = texHeader[textureIndex].offset;
        for (unsigned int mipLevel = 0; mipLevel < texHeader[textureIndex].mipLevels; mipLevel++)
        {
            int width = texHeader[textureIndex].width >> mipLevel;
            int height = texHeader[textureIndex].height >> mipLevel;
            Surface *surface = new Surface(width, height, resourceData + offset);
            textures[textureIndex]->setMipSurface(mipLevel, surface);
            offset += width * height * 4;
        }
#endif
    }

    // Create Render Buffers
    RenderBuffer *vertexBuffers = new RenderBuffer[resourceHeader->numMeshes];
    RenderBuffer *indexBuffers = new RenderBuffer[resourceHeader->numMeshes];
    for (unsigned int meshIndex = 0; meshIndex < resourceHeader->numMeshes; meshIndex++)
    {
        const MeshEntry &entry = meshHeader[meshIndex];
        vertexBuffers[meshIndex].setData(resourceData + entry.offset,
                                         entry.numVertices, sizeof(float) * kAttrsPerVertex);
        indexBuffers[meshIndex].setData(resourceData + entry.offset + entry.numVertices
                                        * kAttrsPerVertex * sizeof(float), entry.numIndices, sizeof(int));
    }

    // Set up render state
    RenderContext *context = new RenderContext(0x1000000);
    RenderTarget *renderTarget = new RenderTarget();
    Surface *colorBuffer = new Surface(FB_WIDTH, FB_HEIGHT, frameBuffer);
    Surface *depthBuffer = new Surface(FB_WIDTH, FB_HEIGHT);
    renderTarget->setColorBuffer(colorBuffer);
    renderTarget->setDepthBuffer(depthBuffer);
    context->bindTarget(renderTarget);
    context->enableDepthBuffer(true);
#if SHOW_DEPTH
    context->bindShader(new DepthShader());
#else
    context->bindShader(new TextureShader());
#endif
    context->setClearColor(0.52, 0.80, 0.98);

    Matrix projectionMatrix = Matrix::getProjectionMatrix(FB_WIDTH, FB_HEIGHT);

    TextureUniforms uniforms;
    uniforms.fLightDirection = Vec3(-1, -0.5, 1).normalized();
    uniforms.fDirectional = 0.5f;
    uniforms.fAmbient = 0.4f;
    float theta = 0.0;

    start_all_threads();

    for (int frame = 0; ; frame++)
    {
        Matrix modelViewMatrix = Matrix::lookAt(Vec3(cos(theta) * 6, 3, sin(theta) * 6), Vec3(0, 3.1, 0),
                                                Vec3(0, 1, 0));
        theta = theta + M_PI / 8;
        if (theta > M_PI * 2)
            theta -= M_PI * 2;

        uniforms.fMVPMatrix = projectionMatrix * modelViewMatrix;
        uniforms.fNormalMatrix = modelViewMatrix.upper3x3();

        context->clearColorBuffer();
        for (unsigned int meshIndex = 0; meshIndex < resourceHeader->numMeshes; meshIndex++)
        {
            const MeshEntry &entry = meshHeader[meshIndex];
            if (entry.textureId != 0xffffffff)
            {
                assert(entry.textureId < resourceHeader->numTextures);
                context->bindTexture(0, textures[entry.textureId]);
                uniforms.fHasTexture = true;
            }
            else
                uniforms.fHasTexture = false;

            context->bindUniforms(&uniforms, sizeof(uniforms));
            context->bindVertexAttrs(&vertexBuffers[meshIndex]);
            context->drawElements(&indexBuffers[meshIndex]);
        }

        clock_t startTime = clock();
        context->finish();
        printf("rendered frame in %d uS\n", clock() - startTime);
    }

    return 0;
}


