// 
// Copyright 2013 Jeff Bush
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

#ifndef __VERTEX_SHADER_H
#define __VERTEX_SHADER_H

#include "vectypes.h"

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
	void processVertices(float *outParams, const float *attribs, int numVertices);

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
	virtual void shadeVertices(vecf16 *outParams, const vecf16 *inAttribs, int mask) = 0;

private:
	int fParamsPerVertex;
	veci16 fParamStepVector;
	int fAttribsPerVertex;
	veci16 fAttribStepVector;
};

}

#endif

