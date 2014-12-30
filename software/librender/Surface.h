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


#ifndef __SURFACE_H
#define __SURFACE_H

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "RenderUtils.h"

namespace librender
{

const int kTileSize = 64; 	// Tile size must be a power of four.

//
// Surface is a piece of 2D bitmap memory.
// Because this contains vector elements, it must be allocated on a cache boundary
//

class Surface
{
public:
	// Width must be a multiple of 16
	Surface(int fbWidth, int fbHeight);
	Surface(int fbWidth, int fbHeight, void *fbBase);

    // Write values to a 4x4 block, with lanes arranged as follows:
    //   0  1  2  3
    //   4  5  6  7
    //   8  9 10 11
    //  12 13 14 15
	void writeBlockMasked(int left, int top, int mask, veci16_t values)
	{
#if COUNT_STATS
		fTotalPixelsWritten += __builtin_popcount(mask);
		fTotalBlocksWritten++;
#endif	
		veci16_t ptrs = f4x4AtOrigin + splati(left * 4 + top * fStride);

		__builtin_nyuzi_scatter_storei_masked(ptrs, values, mask);
	}
	
	// Read values from a 4x4 block, in same order as writeBlockMasked
	veci16_t readBlock(int left, int top) const
	{
        veci16_t ptrs = f4x4AtOrigin + splati(left * 4 + top * fStride);
        return __builtin_nyuzi_gather_loadi(ptrs);
	}
	
	// Set all 32-bit values in a tile to a predefined value.
	void clearTile(int left, int top, unsigned int value);
	
	// Push a tile from the L2 cache back to system memory
	void flushTile(int left, int top);
	
    veci16_t readPixels(veci16_t tx, veci16_t ty, unsigned short mask) const
    {
        veci16_t pointers = (ty * splati(fStride) + tx * splati(kBytesPerPixel)) 
            + splati(fBaseAddress);
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
	
#if COUNT_STATS
	int getTotalPixelsWritten() const
	{
		return fTotalPixelsWritten;
	}

	int getTotalBlocksWritten() const
	{
		return fTotalBlocksWritten;
	}
#endif	

	void *lockBits()
	{
		return (void*) fBaseAddress;
	}

	void *operator new(size_t size) 
	{
		// Because this has vector members, it must be vector width aligned
		return memalign(kCacheLineSize, size);
	}

private:
	void initializePointerVec();
	
	vecu16_t f4x4AtOrigin;
	int fWidth;
	int fHeight;
	int fStride;
	unsigned int fBaseAddress;
#if COUNT_STATS
	int fTotalPixelsWritten;
	int fTotalBlocksWritten;
#endif
};

}

#endif
