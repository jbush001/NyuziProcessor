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

#include <stdint.h>
#include <stdlib.h>
#include "Surface.h"

using namespace librender;

Surface::Surface(int width, int height, void *base)
    :	fWidth(width),
        fHeight(height),
        fStride(width * kBytesPerPixel),
        fBaseAddress((unsigned int) base),
		fOwnedPointer(false)
{
	initializePointerVec();
}

Surface::Surface(int fbWidth, int fbHeight)
    :	fWidth(fbWidth),
        fHeight(fbHeight),
        fStride(fbWidth * kBytesPerPixel),
		fOwnedPointer(true)
{
	fBaseAddress = (unsigned int) memalign(kCacheLineSize, fbWidth * fbHeight * kBytesPerPixel);
	initializePointerVec();
}

Surface::~Surface()
{
	if (fOwnedPointer)
		::free((void*) fBaseAddress);
}

void Surface::initializePointerVec()
{
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

void Surface::clearTileSlow(int left, int top, unsigned int value)
{
    veci16_t *ptr = (veci16_t*)(fBaseAddress + (left + top * fWidth) * kBytesPerPixel);
    const veci16_t kClearColor = splati(value);
	int right = min(kTileSize, fWidth - left);
	int bottom = min(kTileSize, fHeight - top);
    const int kStride = ((fWidth - right) * kBytesPerPixel / sizeof(veci16_t));

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
