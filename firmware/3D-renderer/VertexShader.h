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

#include "utils.h"

namespace render
{

const int kMaxVertexAttribs = 8;
const int kMaxVertexParams = 8;

const int kParamX = 0;
const int kParamY = 1;
const int kParamZ = 2;
const int kParamW = 3;

class VertexShader
{
public:
	// Vertex attributes go in, vertex parameters come out.
	// Attributes are expected to be interleaved: v0a0 v0a1 v1a0 v1a1...
	// This will process up to 16 vertices at a time.
	void processVertices(float *outParams, const float *attribs, int numVertices) const;

	int getNumParams() const
	{
		return fParamsPerVertex;
	}
	
	int getNumAttribs() const
	{
		return fAttribsPerVertex;
	}
	
protected:
	VertexShader(int attribsPerVertex, int paramsPerVertex);
	virtual void shadeVertices(vecf16 *outParams, const vecf16 *inAttribs, int mask) const = 0;

private:
	int fParamsPerVertex;
	veci16 fParamStepVector;
	int fAttribsPerVertex;
	veci16 fAttribStepVector;
};

}

#endif

