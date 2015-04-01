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

#include <stdio.h>
#include "SIMDMath.h"

namespace librender
{

//
// RenderBuffer is a wrapper for an array of geometric data like
// vertex attributes or indices.
//

class RenderBuffer
{
public:
	RenderBuffer()
		:	fData(0),
			fNumElements(0),
			fStride(0)
	{
	}

	RenderBuffer(const void *data, int numElements, int stride)
	{		
		setData(data, numElements, stride);
	}
	
	~RenderBuffer()
	{
	}

	void setData(const void *data, int numElements, int stride)
	{
		fData = data;
		fNumElements = numElements;
		fStride = stride;
	}

	int getNumElements() const
	{
		return fNumElements;
	}
	
	int getStride() const
	{
		return fStride;
	}
	
	int getSize() const
	{
		return fNumElements * fStride;
	}

	const void *getData() const
	{
		return fData;
	}
	
	// Given a packed array of the form a0b0 a0b1... a_1b_0 a_1b_1...
	// Return up to 16 elements packed in a vector: a_mb_n, a_mb_(n+1)...
	veci16_t gatherElements(int index1, int index2, int count) const
	{
		int mask;
		if (count < 16)
			mask = (0xffff0000 >> count) & 0xffff;
		else
			mask = 0xffff;
		
		const veci16_t kStepVector = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
		const veci16_t ptrVec = kStepVector * splati(fStride) + splati(reinterpret_cast<unsigned int>(fData) 
			+ index1 * fStride + index2 * sizeof(unsigned int));
		return __builtin_nyuzi_gather_loadf_masked(ptrVec, mask);
	}

private:
	const void *fData;
	int fNumElements;
	int fStride;
};

}

