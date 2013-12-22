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

#ifndef __PHONG_SHADER
#define __PHONG_SHADER

#define TOON_SHADING 0

#include "VertexShader.h"
#include "PixelShader.h"

//
// The Phong shader interpolates vertex normals across the surface of the triangle
// and computes the dot product at each pixel
//
class PhongVertexShader : public render::VertexShader
{
public:
	PhongVertexShader(int width, int height)
		:	VertexShader(6, 8)
	{
		const float kAspectRatio = float(width) / float(height);
		const float kProjCoeff[4][4] = {
			{ 1.0f / kAspectRatio, 0.0f, 0.0f, 0.0f },
			{ 0.0f, kAspectRatio, 0.0f, 0.0f },
			{ 0.0f, 0.0f, 1.0f, 0.0f },
			{ 0.0f, 0.0f, 1.0f, 0.0f },
		};

		fProjectionMatrix = Matrix(kProjCoeff);
		applyTransform(Matrix());
	}
	
	void applyTransform(const Matrix &mat)
	{
		fModelViewMatrix = fModelViewMatrix * mat;
		fMVPMatrix = fProjectionMatrix * fModelViewMatrix;
		fNormalMatrix = fModelViewMatrix.upper3x3();
	}

	void shadeVertices(vecf16 *outParams, const vecf16 *inAttribs, int mask)
	{
		// Multiply by mvp matrix
		vecf16 coord[4];
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
	PhongPixelShader(render::ParameterInterpolator *interp, render::RenderTarget *target)
		:	PixelShader(interp, target)
	{
		fLightVector[0] = 0.7071067811f;
		fLightVector[1] = 0.7071067811f; 
		fLightVector[2] = 0.0f;

		fDirectional = 0.6f;		
		fAmbient = 0.2f;
	}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outColor[4],
		unsigned short mask)
	{
		// Dot product
		vecf16 dot = -inParams[0] * splatf(fLightVector[0])
			+ -inParams[1] * splatf(fLightVector[1])
			+ -inParams[2] * splatf(fLightVector[2]);
		dot *= splatf(fDirectional);
#if TOON_SHADING
		// Default
		outColor[0] = splatf(0.2f);
		outColor[1] = splatf(0.1f);
		outColor[2] = splatf(0.1f);

		int cmp = __builtin_vp_mask_cmpf_gt(dot, splatf(0.25f));
		outColor[0] = __builtin_vp_blendf(cmp, splatf(0.4f), outColor[0]);
		outColor[1] = __builtin_vp_blendf(cmp, splatf(0.2f), outColor[1]);
		outColor[2] = __builtin_vp_blendf(cmp, splatf(0.2f), outColor[2]);

		cmp = __builtin_vp_mask_cmpf_gt(dot, splatf(0.5f));
		outColor[0] = __builtin_vp_blendf(cmp, splatf(0.6f), outColor[0]);
		outColor[1] = __builtin_vp_blendf(cmp, splatf(0.3f), outColor[1]);
		outColor[2] = __builtin_vp_blendf(cmp, splatf(0.3f), outColor[2]);
		
		cmp = __builtin_vp_mask_cmpf_gt(dot, splatf(0.95f));
		outColor[0] = __builtin_vp_blendf(cmp, splatf(1.0f), outColor[0]);
		outColor[1] = __builtin_vp_blendf(cmp, splatf(0.5f), outColor[1]);
		outColor[2] = __builtin_vp_blendf(cmp, splatf(0.5f), outColor[2]);
#else
		outColor[0] = clampvf(dot) + splatf(fAmbient);
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