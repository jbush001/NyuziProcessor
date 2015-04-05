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

#include <stdint.h>
#include "RenderTarget.h"
#include "Texture.h"
#include "RenderState.h"

namespace librender
{

enum ColorChannel
{
	kColorR,
	kColorG,
	kColorB,
	kColorA
};

enum VertexParam
{
	kParamX,
	kParamY,
	kParamZ,
	kParamW
};


//
// This is overriden by the application to perform vertex and pixel shading.
//

class Shader
{
public:
	virtual void shadeVertices(vecf16_t outParams[], const vecf16_t inAttribs[], 
        const void *uniforms, int mask) const = 0;

	virtual void shadePixels(vecf16_t outColor[4], const vecf16_t inParams[],  
		const void *uniforms, const Texture * const sampler[kMaxTextures], 
		unsigned short mask) const = 0;

	int getNumParams() const
	{
		return fParamsPerVertex;
	}

	int getNumAttribs() const
	{
		return fAttribsPerVertex;
	}

protected:
	Shader(int attribsPerVertex, int paramsPerVertex)
		: fParamsPerVertex(paramsPerVertex),
		  fAttribsPerVertex(attribsPerVertex)
	{}

private:
	int fParamsPerVertex;
	int fAttribsPerVertex;
};

}
