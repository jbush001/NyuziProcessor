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


#include <stdint.h>
#include <stdlib.h>
#include "Surface.h"

namespace librender
{

Surface::Surface(int width, int height, void *base)
    : fWidth(width),
      fHeight(height),
      fStride(width * kBytesPerPixel),
      fBaseAddress(reinterpret_cast<int>(base)),
      fOwnedPointer(false)
{
    initializeOffsetVectors();
}

Surface::Surface(int width, int height)
    : fWidth(width),
      fHeight(height),
      fStride(width * kBytesPerPixel),
      fOwnedPointer(true)
{
    fBaseAddress = reinterpret_cast<int>(memalign(kCacheLineSize,
                                         static_cast<size_t>(width * height * kBytesPerPixel)));
    initializeOffsetVectors();
}

Surface::~Surface()
{
    if (fOwnedPointer)
        ::free(reinterpret_cast<void*>(fBaseAddress));
}

void Surface::initializeOffsetVectors()
{
    // Screen space coordinate offset vector
    float twoOverWidth = 2.0 / fWidth;
    float twoOverHeight = 2.0 / fHeight;
    fXStep =
    {
        0, 1, 2, 3,
        0, 1, 2, 3,
        0, 1, 2, 3,
        0, 1, 2, 3,
    };

    fXStep *= twoOverWidth;

    fYStep =
    {
        0, 0, 0, 0,
        1, 1, 1, 1,
        2, 2, 2, 2,
        3, 3, 3, 3
    };

    fYStep *= twoOverHeight;

    f4x4AtOrigin =
    {
        0, 4, 8, 12,
        0, 4, 8, 12,
        0, 4, 8, 12,
        0, 4, 8, 12
    };

    veci16_t widthOffset =
    {
        0, 0, 0, 0,
        4, 4, 4, 4,
        8, 8, 8, 8,
        12, 12, 12, 12
    };

    f4x4AtOrigin += widthOffset * fWidth + fBaseAddress;
}

void Surface::clearTileSlow(int left, int top, unsigned int value)
{
    veci16_t *ptr = reinterpret_cast<veci16_t*>(fBaseAddress + (left + top * fWidth)
                    * kBytesPerPixel);
    const veci16_t kClearColor = veci16_t(value);
    int right = min(kTileSize, fWidth - left);
    int bottom = min(kTileSize, fHeight - top);
    const int kStride = ((fWidth - right) * kBytesPerPixel / kVectorSize);

    for (int y = 0; y < bottom; y++)
    {
        // XXX LLVM ends up turning this into memset
        for (int x = 0; x < right; x += 16)
            *ptr++ = kClearColor;

        ptr += kStride;
    }
}

// Push a NxN tile from the L2 cache back to system memory
void Surface::flushTile(int left, int top)
{
    int ptr = fBaseAddress + (left + top * fWidth) * kBytesPerPixel;
    int right = min(kTileSize, fWidth - left);
    int bottom = min(kTileSize, fHeight - top);
    const int kStride = (fWidth - right) * kBytesPerPixel;
    for (int y = 0; y < bottom; y++)
    {
        for (int x = 0; x < right; x += 16)
        {
            asm("dflush %0" : : "s" (ptr));
            ptr += kCacheLineSize;
        }

        ptr += kStride;
    }
}

} // namespace librender
