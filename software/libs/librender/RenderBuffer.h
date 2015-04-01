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

class RenderBuffer
{
public:
	RenderBuffer()
		:	fData(0),
			fNumElements(0),
			fElementSize(0)
	{
	}

	RenderBuffer(const void *data, int numElements, int elementSize)
		:	fData(data),
			fNumElements(numElements),
			fElementSize(elementSize)
	{		
	}
	
	~RenderBuffer()
	{
	}

	void setData(const void *data, int numElements, int elementSize)
	{
		fData = data;
		fNumElements = numElements;
		fElementSize = elementSize;
	}

	int getNumElements() const
	{
		return fNumElements;
	}
	
	int getElementSize() const
	{
		return fElementSize;
	}
	
	int getSize() const
	{
		return fNumElements * fElementSize;
	}

	const void *getData() const
	{
		return fData;
	}
	
private:
	const void *fData;
	int fNumElements;
	int fElementSize;
};
