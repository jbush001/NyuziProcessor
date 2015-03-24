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

#include <VertexShader.h>
#include <PixelShader.h>

using namespace librender;

struct CheckerboardUniforms
{
	Matrix fMVPMatrix;
};

class CheckerboardVertexShader : public VertexShader
{
public:
	CheckerboardVertexShader()
		:	VertexShader(5, 6)
	{
	}

	void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, const void *_uniforms,
        int ) const override
	{
        const CheckerboardUniforms *uniforms = static_cast<const CheckerboardUniforms*>(_uniforms);
        
		// Multiply by mvp matrix
		vecf16_t coord[4];
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i];
			
		coord[3] = splatf(1.0f);
		uniforms->fMVPMatrix.mulVec(outParams, coord); 

		// Copy remaining parameters
		outParams[4] = inAttribs[3];
		outParams[5] = inAttribs[4];
	}
};


class CheckerboardPixelShader : public librender::PixelShader
{
public:
	void shadePixels(const vecf16_t inParams[16], vecf16_t outColor[4],
		const void *, const Texture * const [kMaxTextures],
		unsigned short ) const override
	{
		int check = __builtin_nyuzi_mask_cmpi_eq(((__builtin_convertvector(inParams[0] * splatf(4), veci16_t) & splati(1))
			^ (__builtin_convertvector(inParams[1] * splatf(4), veci16_t) & splati(1))), splati(0));
		outColor[kColorR] = outColor[kColorG] = outColor[kColorB] = __builtin_nyuzi_vector_mixf(check, splatf(1.0),
			splatf(0.0));
		outColor[kColorA] = splatf(1.0);
	}
};

