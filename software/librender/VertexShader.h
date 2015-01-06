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


#ifndef __VERTEX_SHADER_H
#define __VERTEX_SHADER_H

#include <stdlib.h>
#include "RenderUtils.h"

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
		return memalign(kCacheLineSize, size);
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

#endif

