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
#include "SIMDMath.h"

namespace librender
{

const int kCacheLineSize = 64;
const int kBytesPerPixel = 4;
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
    // This allocates surface memory and frees it automatically.
    Surface(int width, int height);

    // This will use the passed pointer as surface memory and will
    // not attempt to free it.
    Surface(int width, int height, void *base);

    ~Surface();

    Surface(const Surface&) = delete;
    Surface& operator=(const Surface&) = delete;

    // Write values to a 4x4 block, with lanes arranged as follows:
    //   0  1  2  3
    //   4  5  6  7
    //   8  9 10 11
    //  12 13 14 15
    void writeBlockMasked(int left, int top, vmask_t mask, vecu16_t values)
    {
        veci16_t ptrs = f4x4AtOrigin + left * 4 + top * fStride;
        __builtin_nyuzi_scatter_storei_masked(ptrs, values, mask);
    }

    // Read values from a 4x4 block, in same order as writeBlockMasked
    vecu16_t readBlock(int left, int top) const
    {
        veci16_t ptrs = f4x4AtOrigin + left * 4 + top * fStride;
        return __builtin_nyuzi_gather_loadi(ptrs);
    }

    // Set all 32-bit values in a tile to a predefined value.
    void clearTile(int left, int top, unsigned int value)
    {
        if (kTileSize == 64 && fWidth - left >= 64 && fHeight - top >= 64)
        {
            // Fast clear using block stores
            vecu16_t vval = value;
            vecu16_t *ptr = reinterpret_cast<vecu16_t*>(fBaseAddress + (left + top * fWidth) * kBytesPerPixel);
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
            clearTileSlow(left, top, value);
    }

    // Push a tile from the L2 cache back to system memory
    void flushTile(int left, int top);

    veci16_t readPixels(veci16_t tx, veci16_t ty, vmask_t mask) const
    {
        veci16_t pointers = (ty * fStride + tx * kBytesPerPixel)
                            + fBaseAddress;
        return __builtin_nyuzi_gather_loadi_masked(pointers, mask);
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

private:
    void initializeOffsetVectors();
    void clearTileSlow(int left, int top, unsigned int value);

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

};

} // namespace librender
