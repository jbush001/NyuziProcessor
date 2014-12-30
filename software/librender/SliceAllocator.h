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

#ifndef __SLICE_ALLOCATOR_H
#define __SLICE_ALLOCATOR_H

#include <assert.h>
#include <stddef.h>

namespace render
{

//
// This very quickly allocates transient objects by slicing them off the end
// of a larger chunk.  It can only free all objects at once.
//

class SliceAllocator
{
public:
	SliceAllocator(int arenaSize = 0x100000)
		:	fArenaBase((char*) malloc(arenaSize)),
			fTotalSize(arenaSize),
			fNextAlloc((char*) fArenaBase)
	{
	}
	
	~SliceAllocator()
	{
		free(fArenaBase);
	}

	// This is thread safe.  Alignment must be a power of 2
	void *alloc(size_t size, size_t alignment = 4) 
	{
		char *nextAlloc;
		char *alignedAlloc;
		
		do
		{
			nextAlloc = fNextAlloc;
			alignedAlloc = reinterpret_cast<char*>((reinterpret_cast<unsigned int>(nextAlloc) 
				+ alignment - 1) & ~(alignment - 1));
			assert(alignedAlloc + size < fArenaBase + fTotalSize);
		}
		while (!__sync_bool_compare_and_swap(&fNextAlloc, nextAlloc, alignedAlloc + size));
		
		return alignedAlloc;
	}

	// This is not thread safe.  Caller must guarantee no other threads 
	// are calling other methods on the allocator when this is called
	void reset() 
	{
		fNextAlloc = fArenaBase;
	}

private:	
	char *fArenaBase;
	unsigned int fTotalSize;
	char *fNextAlloc;
};

}

#endif
