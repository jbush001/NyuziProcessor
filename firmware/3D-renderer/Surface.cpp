// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
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
        fBaseAddress = (unsigned int) memalign(kCacheLineSize, fbWidth * fbHeight * kBytesPerPixel);

    f4x4AtOrigin = {
		fBaseAddress,
   		fBaseAddress + 4,
   		fBaseAddress + 8, 
   		fBaseAddress + 12,
   		fBaseAddress + (fWidth * 4),
   		fBaseAddress + (fWidth * 4) + 4,
   		fBaseAddress + (fWidth * 4) + 8, 
   		fBaseAddress + (fWidth * 4) + 12,
   		fBaseAddress + (fWidth * 8),
   		fBaseAddress + (fWidth * 8) + 4,
   		fBaseAddress + (fWidth * 8) + 8, 
   		fBaseAddress + (fWidth * 8) + 12,
   		fBaseAddress + (fWidth * 12),
   		fBaseAddress + (fWidth * 12) + 4,
   		fBaseAddress + (fWidth * 12) + 8, 
   		fBaseAddress + (fWidth * 12) + 12
	};
}

void Surface::clearTile(int left, int top, unsigned int value)
{
    veci16 *ptr = (veci16*)(fBaseAddress + (left + top * fWidth) * kBytesPerPixel);
    const veci16 kClearColor = splati(value);
	int right = min(kTileSize, fWidth - left);
	int bottom = min(kTileSize, fHeight - top);
    const int kStride = ((fWidth - right) * kBytesPerPixel / sizeof(veci16));
    
    for (int y = 0; y < bottom; y++)
    {
        for (int x = 0; x < right; x += 16)
            *ptr++ = kClearColor;
        
        ptr += kStride;
    }
}

// Push a NxN tile from the L2 cache back to system memory
void Surface::flushTile(int left, int top)
{
    unsigned int ptr = fBaseAddress + (left + top * fWidth) * kBytesPerPixel;
	int right = min(kTileSize, fWidth - left);
	int bottom = min(kTileSize, fHeight - top);
    const int kStride = (fWidth - right) * kBytesPerPixel;
    for (int y = 0; y < bottom; y++)
    {
        for (int x = 0; x < right; x += 16)
        {
            dflush(ptr);
            ptr += kCacheLineSize;
        }
        
        ptr += kStride;
    }
}