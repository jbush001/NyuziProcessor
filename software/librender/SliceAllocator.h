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

#include <assert.h>
#include <stddef.h>

namespace librender
{

//
// This very quickly allocates short-lived objects by slicing them off the end
// of a larger chunk.  It can only free all objects at once.
//

class SliceAllocator
{
public:
	SliceAllocator(int arenaSize)
		:	fArenaBase((char*) malloc(arenaSize)),
			fTotalSize(arenaSize),
			fNextAlloc((char*) fArenaBase)
	{
	}

	SliceAllocator(const SliceAllocator&) = delete;
	SliceAllocator& operator=(const SliceAllocator&) = delete;
	
	~SliceAllocator()
	{
		free(fArenaBase);
	}

	// This is thread safe and lock-free. Alignment must be a power of 2
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

	size_t bytesUsed() const
	{
		return fNextAlloc - fArenaBase;
	}

private:	
	char *fArenaBase;
	unsigned int fTotalSize;
	char * volatile fNextAlloc;
};

}

inline void *operator new(size_t size, librender::SliceAllocator &allocator)
{
	return allocator.alloc(size);
}

inline void *operator new[] (size_t size, librender::SliceAllocator &allocator)
{
	return allocator.alloc(size);
}
