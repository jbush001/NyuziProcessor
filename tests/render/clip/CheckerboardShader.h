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


#ifndef __Checkerboard_SHADER_H
#define __Checkerboard_SHADER_H

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
		int check = __builtin_nyuzi_mask_cmpi_eq(((__builtin_nyuzi_vftoi(inParams[0] * splatf(4)) & splati(1))
			^ (__builtin_nyuzi_vftoi(inParams[1] * splatf(4)) & splati(1))), splati(0));
		outColor[kColorR] = outColor[kColorG] = outColor[kColorB] = __builtin_nyuzi_vector_mixf(check, splatf(1.0),
			splatf(0.0));
		outColor[kColorA] = splatf(1.0);
	}
};

#endif

