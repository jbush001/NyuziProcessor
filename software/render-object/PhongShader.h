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

#include "VertexShader.h"
#include "PixelShader.h"

using namespace render;

//
// The Phong shader interpolates vertex normals across the surface of the triangle
// and computes the dot product at each pixel
//
class PhongVertexShader : public render::VertexShader
{
public:
	PhongVertexShader()
		:	VertexShader(6, 8)
	{
	}

	void setProjectionMatrix(const Matrix &mat)
	{
		fProjectionMatrix = mat;
		fMVPMatrix = fProjectionMatrix * fModelViewMatrix;
		fNormalMatrix = fModelViewMatrix.upper3x3();
	}
	
	void applyTransform(const Matrix &mat)
	{
		fModelViewMatrix = fModelViewMatrix * mat;
		fMVPMatrix = fProjectionMatrix * fModelViewMatrix;
		fNormalMatrix = fModelViewMatrix.upper3x3();
	}

	void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, int mask) const override
	{
		// Multiply by mvp matrix
		vecf16_t coord[4];
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i];
			
		coord[3] = splatf(1.0f);
		fMVPMatrix.mulVec(outParams, coord); 

		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i + 3];
			
		coord[3] = splatf(1.0f);
		
		fNormalMatrix.mulVec(outParams + 4, coord); 
	}

private:
	Matrix fMVPMatrix;
	Matrix fProjectionMatrix;
	Matrix fModelViewMatrix;
	Matrix fNormalMatrix;
};

class PhongPixelShader : public render::PixelShader
{
public:
	PhongPixelShader(render::RenderTarget *target)
		:	PixelShader(target)
	{
		fLightVector[0] = 0.7071067811f;
		fLightVector[1] = 0.7071067811f; 
		fLightVector[2] = 0.0f;

		fDirectional = 0.6f;		
		fAmbient = 0.2f;
	}
	
	virtual void shadePixels(const vecf16_t inParams[16], vecf16_t outColor[4],
		unsigned short mask) const override
	{
		// Dot product
		vecf16_t dot = -inParams[0] * splatf(fLightVector[0])
			+ -inParams[1] * splatf(fLightVector[1])
			+ -inParams[2] * splatf(fLightVector[2]);
		dot *= splatf(fDirectional);
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
		outColor[0] = render::clampvf(dot) + splatf(fAmbient);
		outColor[1] = outColor[2] = splatf(0.0f);
#endif
		outColor[3] = splatf(1.0f);	// Alpha
	}

private:
	float fLightVector[3];
	float fAmbient;
	float fDirectional;
};

#endif
