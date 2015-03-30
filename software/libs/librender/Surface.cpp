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
		// XXX LLVM ends up turning this into memset
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
			asm("dflush %0" : : "s" (ptr));
			ptr += kCacheLineSize;
		}

		ptr += kStride;
	}
}
