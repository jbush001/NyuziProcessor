// 
// Copyright 2013 Jeff Bush
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

#include "Surface.h"

using namespace render;

Surface::Surface(int fbBase, int fbWidth, int fbHeight)
    :	fWidth(fbWidth),
        fHeight(fbHeight),
        fStride(fbWidth * kBytesPerPixel),
        fBaseAddress(fbBase)
#if COUNT_STATS
        , fTotalPixelsWritten(0),
        fTotalBlocksWritten(0)
#endif
{
    if (fBaseAddress == 0)
        fBaseAddress = (unsigned int) allocMem(fbWidth * fbHeight * kBytesPerPixel);

    f4x4AtOrigin[0] = fBaseAddress;
    f4x4AtOrigin[1] = fBaseAddress + 4;
    f4x4AtOrigin[2] = fBaseAddress + 8; 
    f4x4AtOrigin[3] = fBaseAddress + 12;
    f4x4AtOrigin[4] = fBaseAddress + (fWidth * 4);
    f4x4AtOrigin[5] = fBaseAddress + (fWidth * 4) + 4;
    f4x4AtOrigin[6] = fBaseAddress + (fWidth * 4) + 8; 
    f4x4AtOrigin[7] = fBaseAddress + (fWidth * 4) + 12;
    f4x4AtOrigin[8] = fBaseAddress + (fWidth * 8);
    f4x4AtOrigin[9] = fBaseAddress + (fWidth * 8) + 4;
    f4x4AtOrigin[10] = fBaseAddress + (fWidth * 8) + 8; 
    f4x4AtOrigin[11] = fBaseAddress + (fWidth * 8) + 12;
    f4x4AtOrigin[12] = fBaseAddress + (fWidth * 12);
    f4x4AtOrigin[13] = fBaseAddress + (fWidth * 12) + 4;
    f4x4AtOrigin[14] = fBaseAddress + (fWidth * 12) + 8; 
    f4x4AtOrigin[15] = fBaseAddress + (fWidth * 12) + 12;
}

void Surface::clearTile(int left, int top, unsigned int value)
{
    veci16 *ptr = (veci16*)(fBaseAddress + left * kBytesPerPixel + top * fWidth 
        * kBytesPerPixel);
    const veci16 kClearColor = splati(value);
    const int kStride = ((fWidth - kTileSize) * kBytesPerPixel / sizeof(veci16));
    
    for (int y = 0; y < kTileSize; y++)
    {
        for (int x = 0; x < kTileSize; x += 16)
            *ptr++ = kClearColor;
        
        ptr += kStride;
    }
}

// Push a NxN tile from the L2 cache back to system memory
void Surface::flushTile(int left, int top)
{
    const int kStride = (fWidth - kTileSize) * kBytesPerPixel;
    unsigned int ptr = fBaseAddress + left * kBytesPerPixel + top * fWidth 
        * kBytesPerPixel;
    for (int y = 0; y < kTileSize; y++)
    {
        for (int x = 0; x < kTileSize; x += 16)
        {
            dflush(ptr);
            ptr += kCacheLineSize;
        }
        
        ptr += kStride;
    }
}