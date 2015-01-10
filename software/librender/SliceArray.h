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
	
//
// Variable sized array that uses SliceAllocator. reset() must be called
// on this object before using it again after reset() is called on the
// allocator. This uses a fast, lock-free append.
// BUCKET size should be large enough to avoid needing multiple allocations,
// but small enough that it doesn't waste memory.
//
	
template <typename T, int BUCKET_SIZE>
class SliceArray
{
private:
	struct Bucket;

public:
	SliceArray() {}
	SliceArray(const SliceArray&) = delete;
	SliceArray& operator=(const SliceArray&) = delete;
	
	void setAllocator(SliceAllocator *allocator)
	{
		fAllocator = allocator;
	}
	
	void sort()
	{
		if (!fFirstBucket)
			return;		// Empty

		// Insertion sort
		for (iterator i = begin().next(), e = end(); i != e; ++i)
		{
			iterator j = i;
			while (j != begin() && *j.prev() > *j)
			{
				// swap
				T temp = *j;
				*j = *j.prev();
				*j.prev() = temp;
				--j;
			}
		}
	}
	
	void append(const T &copyFrom)
	{
		int index;
		Bucket *bucket;
		
		while (true)
		{
			// index and bucket must be read in this order to avoid a race 
			// condition.  Because these are volatile, the compiler won't 
			// reorder them.
			index = fNextBucketIndex;
			bucket = fLastBucket;
			if (index == BUCKET_SIZE || bucket == nullptr)
			{
				allocateBucket();
				continue;
			}

			if (__sync_bool_compare_and_swap(&fNextBucketIndex, index, index + 1))
				break;
		}

		bucket->items[index] = copyFrom;
	}
	
	void reset()
	{
		// Manually invoke destructor on items.
		for (Bucket *bucket = fFirstBucket; bucket; bucket = bucket->next)
			bucket->~Bucket();

		fFirstBucket = nullptr;
		fLastBucket = nullptr;
		fNextBucketIndex = 0;
	}

	class iterator
	{
	public:
		bool operator!=(const iterator &iter)
		{
			return fBucket != iter.fBucket || fIndex != iter.fIndex;
		}

		bool operator==(const iterator &iter)
		{
			return fBucket == iter.fBucket && fIndex == iter.fIndex;
		}
		
		const iterator &operator++()
		{
			// subtle: don't advance to next bucket if it is
			// null, otherwise next() will not iterate to end()
			// when it is on last item.
			if (++fIndex == BUCKET_SIZE && fBucket->next)
			{
				fBucket = fBucket->next;
				fIndex = 0;
			}

			return *this;
		}
		
		const iterator &operator--()
		{
			if (--fIndex < 0)
			{
				fBucket = fBucket->prev;
				fIndex = BUCKET_SIZE - 1;
			}
			
			return *this;
		}
		
		T& operator*() const
		{
			return fBucket->items[fIndex];
		}

		iterator next() const
		{
			iterator tmp = *this;
			++tmp;
			return tmp;
		}
		
		iterator prev() const
		{
			iterator tmp = *this;
			--tmp;
			return tmp;
		}

	private:
		friend class SliceArray;
		
		iterator(Bucket *bucket, int index)
			: 	fBucket(bucket),
				fIndex(index)
		{}

		Bucket *fBucket;
		int fIndex;	// Index in current bucket
	};

	iterator begin() const
	{
		return iterator(fFirstBucket, 0);
	}
	
	iterator end() const
	{
		return iterator(fLastBucket, fNextBucketIndex);
	}
	
private:
	struct Bucket
	{
		Bucket *next = nullptr;
		Bucket *prev = nullptr;
		T items[BUCKET_SIZE];
	};

	void allocateBucket()
	{
		// Lock
		do
		{
			while (fLock)
				;
		}
		while (!__sync_bool_compare_and_swap(&fLock, 0, 1));
		
		// Check first that someone didn't beat us to allocating
		if (fNextBucketIndex == BUCKET_SIZE || fLastBucket == nullptr)
		{
			if (fLastBucket)
			{
				// Append to end of chain
				Bucket *newBucket = new (fAllocator) Bucket;
				newBucket->prev = fLastBucket;
				fLastBucket->next = newBucket;
				fLastBucket = newBucket;
			}
			else
			{
				// Allocate initial bucket
				fFirstBucket = new (fAllocator) Bucket;
				fLastBucket = fFirstBucket;
			}
		
			// We must update fNextBucketIndex after fLastBucket to avoid a race
			// condition.  Because they are volatile, the compiler shouldn't reorder them.
			fNextBucketIndex = 0;
		}
		
		fLock = 0;
		__sync_synchronize();
	}

	static int compareElements(const void *t1, const void *t2)
	{
		return *reinterpret_cast<const T*>(t1) > *reinterpret_cast<const T*>(t2) ? 1 : -1;
	}

	Bucket *fFirstBucket = nullptr;
	Bucket * volatile fLastBucket = nullptr;
	volatile int fNextBucketIndex = 0; // When the bucket is full, this will equal BUCKET_SIZE
	SliceAllocator *fAllocator = nullptr;
	volatile int fLock = 0;
};

}

#endif
