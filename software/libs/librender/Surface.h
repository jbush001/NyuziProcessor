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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "SIMDMath.h"

namespace librender
{

const int kCacheLineSize = 64;
const int kTileSize = 64;
const int kVectorSize = 64;

static_assert(__builtin_clz(kTileSize) & 1, "Tile size must be power of four");

//
// Surface is a chunk of 2D bitmap memory.
// Because this contains vector elements, this structure must be aligned to vector width.
// If this is to be used as a destination, the width and height must be a multiple of
// 64 bytes.
//

class Surface
{
public:
    enum ColorSpace
    {
        RGBA8888,
        FLOAT,
        GRAY8
    };

    // If base is not null, this will use it as surface memory and will
    // not attempt to free it. Otherwise this will allocate its own
    // memory to use.
    Surface(int width, int height, ColorSpace, void *base = nullptr);

    ~Surface();

    Surface(const Surface&) = delete;
    Surface& operator=(const Surface&) = delete;

    // Write values to a 4x4 block, with lanes arranged as follows:
    //   0  1  2  3
    //   4  5  6  7
    //   8  9 10 11
    //  12 13 14 15
    // XXX hardcoded for RGBA8888 color space
    void writeBlockMasked(int left, int top, vmask_t mask, vecu16_t values)
    {
        veci16_t ptrs = f4x4AtOrigin + left * 4 + top * fStride;
        __builtin_nyuzi_scatter_storei_masked(ptrs, values, mask);
    }

    // Read values from a 4x4 block, in same order as writeBlockMasked
    // XXX hardcoded for RGBA8888 color space
    vecu16_t readBlock(int left, int top) const
    {
        veci16_t ptrs = f4x4AtOrigin + left * 4 + top * fStride;
        return __builtin_nyuzi_gather_loadi(ptrs);
    }

    // Set all 32-bit values in a tile to a predefined value.
    void clearTile(int left, int top, unsigned int value)
    {
        if (kTileSize == 64 && fWidth - left >= 64 && fHeight - top >=
            64 && (fColorSpace == RGBA8888 || fColorSpace == FLOAT))
        {
            // Fast clear using block stores
            vecu16_t vval = value;
            vecu16_t *ptr = reinterpret_cast<vecu16_t*>(fBaseAddress + (left + top * fWidth)
                * fBytesPerPixel);
            const int kStride = fStride / kCacheLineSize;
            for (int y = 0; y < 64; y++)
            {
                ptr[0] = vval;
                ptr[1] = vval;
                ptr[2] = vval;
                ptr[3] = vval;
                ptr += kStride;
            }
        }
        else
            slowClearTile(left, top, value);
    }

    // Push a tile from the L2 cache back to system memory
    void flushTile(int left, int top);

    void readPixels(veci16_t tx, veci16_t ty, vmask_t mask, vecf16_t *outColor) const
    {
        veci16_t pointers = (ty * fStride + tx * fBytesPerPixel)
                            + fBaseAddress;
        veci16_t packedColor = __builtin_nyuzi_gather_loadi_masked(pointers & ~3, mask);
        const float kOneOver255 = 1.0 / 255.0;
        switch (fColorSpace)
        {
            case RGBA8888:
                outColor[0] = __builtin_convertvector(packedColor & 255, vecf16_t)
                                    * kOneOver255;
                outColor[1] = __builtin_convertvector((packedColor >> 8) & 255,
                                    vecf16_t) * kOneOver255;
                outColor[2] = __builtin_convertvector((packedColor >> 16) & 255,
                                    vecf16_t) * kOneOver255;
                outColor[3] = __builtin_convertvector((packedColor >> 24) & 255,
                                    vecf16_t) * kOneOver255;
                break;

            case GRAY8:
                packedColor = (packedColor >> ((pointers & 3) * 8)) & 0xff;
                outColor[0] = __builtin_convertvector(packedColor, vecf16_t)
                    * kOneOver255;
                outColor[1] = outColor[2] = outColor[3];
                break;

            case FLOAT:
                outColor[0] = reinterpret_cast<vecf16_t>(packedColor);
                outColor[1] = outColor[2] = outColor[3];
                break;
        }
    }

    inline int getWidth() const
    {
        return fWidth;
    }

    inline int getHeight() const
    {
        return fHeight;
    }

    inline int getStride() const
    {
        return fStride;
    }

    void *bits() const
    {
        return reinterpret_cast<void*>(fBaseAddress);
    }

    void *operator new(size_t size)
    {
        // Because this structure has vector members, it must be vector width aligned
        return memalign(sizeof(vecu16_t), size);
    }

    vecf16_t getXStep() const
    {
        return fXStep;
    }

    vecf16_t getYStep() const
    {
        return fYStep;
    }

    ColorSpace getColorSpace() const
    {
        return fColorSpace;
    }

private:
    void initializeOffsetVectors();
    void slowClearTile(int left, int top, unsigned int value);

    veci16_t f4x4AtOrigin;

    // For each pixel in a 4x4 grid, these represent the distance in
    // screen coordinates (-1.0 to 1.0) from the upper left pixel.
    vecf16_t fXStep;
    vecf16_t fYStep;

    int fWidth;
    int fHeight;
    int fStride;
    int fBaseAddress;
    bool fOwnedPointer;
    ColorSpace fColorSpace;
    int fBytesPerPixel;
};

} // namespace librender
