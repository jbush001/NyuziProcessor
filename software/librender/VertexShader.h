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

#include <stdlib.h>
#include "SIMDMath.h"

namespace librender
{
	
enum VertexParam
{
	kParamX,
	kParamY,
	kParamZ,
	kParamW
};

// This is subclassed by client programs to compute vertex parameters.
// Because this contains vector elements, it must be allocated on a cache boundary
class VertexShader
{
public:
	// Vertex attributes go in, vertex parameters come out.
	// Attributes are expected to be interleaved: v0a0 v0a1 v1a0 v1a1...
	// This will process up to 16 vertices at a time.
	void processVertices(float *outParams, const float *attribs, const void *inUniforms, 
        int numVertices) const;

	int getNumParams() const
	{
		return fParamsPerVertex;
	}
	
	int getNumAttribs() const
	{
		return fAttribsPerVertex;
	}
	
	void *operator new(size_t size) 
	{
		// Because this has vector members, it must be vector width aligned
		return memalign(sizeof(veci16_t), size);
	}
	
protected:
	VertexShader(int attribsPerVertex, int paramsPerVertex);
	virtual void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, 
        const void *inUniforms, int mask) const = 0;

private:
	veci16_t fParamStepVector;
	veci16_t fAttribStepVector;
	int fParamsPerVertex;
	int fAttribsPerVertex;
};

}

