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


#ifndef __PHONG_SHADER
#define __PHONG_SHADER

#define TOON_SHADING 0

#include <VertexShader.h>
#include <PixelShader.h>

using namespace librender;

struct PhongUniforms
{
	Matrix fMVPMatrix;
	Matrix fNormalMatrix;
	float fLightVector[3];
	float fAmbient;
	float fDirectional;
};

//
// The Phong shader interpolates vertex normals across the surface of the triangle
// and computes the dot product at each pixel
//
class PhongVertexShader : public librender::VertexShader
{
public:
	PhongVertexShader()
		:	VertexShader(6, 8)
	{
	}

	void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, const void *_uniforms,
        int mask) const override
	{
        const PhongUniforms *uniforms = static_cast<const PhongUniforms*>(_uniforms);
        
		// Multiply by mvp matrix
		vecf16_t coord[4];
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i];
			
		coord[3] = splatf(1.0f);
		uniforms->fMVPMatrix.mulVec(outParams, coord); 

		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i + 3];
			
		coord[3] = splatf(1.0f);
		
		uniforms->fNormalMatrix.mulVec(outParams + 4, coord); 
	}
};

namespace 
{

// simple newton's method vector square root.
vecf16_t vsqrt(vecf16_t value)
{
	vecf16_t guess = value;
	for (int iteration = 0; iteration < 6; iteration++)
		guess = ((value / guess) + guess) / splatf(2.0f);

	return guess;	
}
	
}

class PhongPixelShader : public librender::PixelShader
{
public:
	virtual void shadePixels(const vecf16_t inParams[16], vecf16_t outColor[4],
		const void *_castToUniforms, unsigned short mask) const override
	{
		const PhongUniforms *uniforms = static_cast<const PhongUniforms*>(_castToUniforms);
		
		// Normalize surface normal.
		vecf16_t nx = inParams[0];
		vecf16_t ny = inParams[1];
		vecf16_t nz = inParams[2];
		vecf16_t mag = vsqrt(nx * nx + ny * ny + nz * nz);
		nx /= mag;
		ny /= mag;
		nz /= mag;

		// Dot product determines lambertian reflection
		vecf16_t dot = -nx * splatf(uniforms->fLightVector[0])
			+ -ny * splatf(uniforms->fLightVector[1])
			+ -nz * splatf(uniforms->fLightVector[2]);
		dot *= splatf(uniforms->fDirectional);
#if TOON_SHADING
		// Default
		outColor[0] = splatf(0.2f);
		outColor[1] = splatf(0.1f);
		outColor[2] = splatf(0.1f);

		int cmp = __builtin_nyuzi_mask_cmpf_gt(dot, splatf(0.25f));
		outColor[0] = __builtin_nyuzi_vector_mixf(cmp, splatf(0.4f), outColor[0]);
		outColor[1] = __builtin_nyuzi_vector_mixf(cmp, splatf(0.2f), outColor[1]);
		outColor[2] = __builtin_nyuzi_vector_mixf(cmp, splatf(0.2f), outColor[2]);

		cmp = __builtin_nyuzi_mask_cmpf_gt(dot, splatf(0.5f));
		outColor[0] = __builtin_nyuzi_vector_mixf(cmp, splatf(0.6f), outColor[0]);
		outColor[1] = __builtin_nyuzi_vector_mixf(cmp, splatf(0.3f), outColor[1]);
		outColor[2] = __builtin_nyuzi_vector_mixf(cmp, splatf(0.3f), outColor[2]);
		
		cmp = __builtin_nyuzi_mask_cmpf_gt(dot, splatf(0.95f));
		outColor[0] = __builtin_nyuzi_vector_mixf(cmp, splatf(1.0f), outColor[0]);
		outColor[1] = __builtin_nyuzi_vector_mixf(cmp, splatf(0.5f), outColor[1]);
		outColor[2] = __builtin_nyuzi_vector_mixf(cmp, splatf(0.5f), outColor[2]);
#else
		outColor[0] = librender::clampvf(dot) + splatf(uniforms->fAmbient);
		outColor[1] = outColor[2] = splatf(0.0f);
#endif
		outColor[3] = splatf(1.0f);	// Alpha
	}
};

#endif
