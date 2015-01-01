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

#ifndef __SLICE_ARRAY_H
#define __SLICE_ARRAY_H

#include "SliceAllocator.h"

namespace librender
{
	
// Variable sized array that uses SliceAllocator.  reset() must be called
// on this object before using it again after reset() is called on the
// allocator. This uses a fast, wait-free append.
template <typename T, int BUCKET_SIZE, int MAX_BUCKETS>
class SliceArray
{
public:
	SliceArray()
		:	fAllocator(nullptr),
			fSize(0),
			fLock(0)
	{
		reset();
	}
	
	void setAllocator(SliceAllocator *allocator)
	{
		fAllocator = allocator;
	}
	
	static int compareElements(const void *t1, const void *t2)
	{
		return *reinterpret_cast<const T*>(t1) > *reinterpret_cast<const T*>(t2) ? 1 : -1;
	}
	
	void sort()
	{
		if (fSize <= BUCKET_SIZE)
		{
			// Fast path, single bucket, sort in place
			qsort(fBuckets[0], fSize, sizeof(T), compareElements);
		}
		else
		{
			// Sort across multiple buckets
			for (int i = 0; i < count() - 1; i++)
			{
				for (int j = i + 1; j < count(); j++)
				{
					if ((*this)[i] > (*this)[j])
					{
						T tmp = (*this)[i];
						(*this)[i] = (*this)[j];
						(*this)[j] = tmp;
					}
				}
			}
		}
	}

	T &append()
	{
		int index = __sync_fetch_and_add(&fSize, 1);
		int bucketIndex = index / BUCKET_SIZE;
		assert(bucketIndex < BUCKET_SIZE * MAX_BUCKETS);
		if (!fBuckets[bucketIndex])
		{
			// Grow array
			// lock
			while (!__sync_bool_compare_and_swap(&fLock, 0, 1))
				;
			
			// Check if someone beat us to adding a new bucket
			if (!fBuckets[bucketIndex])
				fBuckets[bucketIndex] = (T*) fAllocator->alloc(sizeof(T) * BUCKET_SIZE);

			fLock = 0;
			__sync_synchronize();
		}

		return fBuckets[bucketIndex][index % BUCKET_SIZE];
	}
	
	const T& append(const T &copyFrom)
	{
		append() = copyFrom;
		return copyFrom;
	}

	T& append(T &copyFrom)
	{
		append() = copyFrom;
		return copyFrom;
	}
	
	T &operator[](size_t index)
	{
		return fBuckets[index / BUCKET_SIZE][index % BUCKET_SIZE];
	}

	const T &operator[](size_t index) const
	{
		return fBuckets[index / BUCKET_SIZE][index % BUCKET_SIZE];
	}
	
	int count() const
	{
		return fSize;
	}
	
	void reset()
	{
		for (int i = 0; i < MAX_BUCKETS; i++)
			fBuckets[i] = nullptr;
		
		fSize = 0;
	}

	class iterator
	{
	public:
		bool operator!=(const iterator &iter)
		{
			return fIndex != iter.fIndex || fBucket != iter.fBucket;
		}
		
		iterator operator++()
		{
			if (++fIndex == BUCKET_SIZE)
			{
				fIndex = 0;
				fBucket++;
				fPtr = fArray->fBuckets[fBucket];
			}
			else
				fPtr++;

			return *this;
		}
		
		T& operator*() const
		{
			return *fPtr;
		}
					
	private:
		iterator(SliceArray *array, int bucket, int index)
			: 	fArray(array),
				fBucket(bucket),
				fIndex(index),
				fPtr(fArray->fBuckets[fBucket])
		{}

		SliceArray *fArray;
		int fBucket;
		int fIndex;
		friend class SliceArray;
		T *fPtr;
	};

	iterator begin()
	{
		return iterator(this, 0, 0);
	}
	
	iterator end()
	{
		return iterator(this, fSize / BUCKET_SIZE, fSize % BUCKET_SIZE);
	}
	
private:
	SliceAllocator *fAllocator;
	T *fBuckets[MAX_BUCKETS];
	volatile int fSize;
	int fLock;
};

}

#endif
