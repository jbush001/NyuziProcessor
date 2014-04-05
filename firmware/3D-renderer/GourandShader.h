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

#ifndef __GOURAND_SHADER_H
#define __GOURAND_SHADER_H

#include "VertexShader.h"
#include "PixelShader.h"

//
// The Gourand shader computes the dot product of the vertex normal at each
// pixel and then interpolates the resulting color values across the triangle.
//
class GourandVertexShader : public render::VertexShader
{
public:
	GourandVertexShader(int width, int height)
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

		fLightVector[0] = 0.7071067811f;
		fLightVector[1] = 0.7071067811f; 
		fLightVector[2] = 0.0f;

		fDirectional = 0.6f;		
		fAmbient = 0.2f;
	}
	
	void applyTransform(const Matrix &mat)
	{
		fModelViewMatrix = fModelViewMatrix * mat;
		fMVPMatrix = fProjectionMatrix * fModelViewMatrix;
		fNormalMatrix = fModelViewMatrix.upper3x3();
	}

	void shadeVertices(vecf16 *outParams, const vecf16 *inAttribs, int mask) const override
	{
		// Multiply by mvp matrix
		vecf16 coord[4];
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i];
			
		coord[3] = splatf(1.0f);
		fMVPMatrix.mulVec(outParams, coord); 

		// Determine light at this vertex
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i + 3];
			
		coord[3] = splatf(1.0f);
		vecf16 transformedNormal[4];
		fNormalMatrix.mulVec(transformedNormal, coord); 

		// Dot product
		vecf16 dot = -transformedNormal[0] * splatf(fLightVector[0])
			+ -transformedNormal[1] * splatf(fLightVector[1])
			+ -transformedNormal[2] * splatf(fLightVector[2]);
		dot *= splatf(fDirectional);
		
		// Compute the color at this vertex, which will be interpolated
		outParams[5] = outParams[6] = splatf(0.0f);
		outParams[4] = clampvf(dot) + splatf(fAmbient);
		outParams[7] = splatf(1.0f);
	}

private:
	Matrix fMVPMatrix;
	Matrix fProjectionMatrix;
	Matrix fModelViewMatrix;
	Matrix fNormalMatrix;
	float fLightVector[3];
	float fAmbient;
	float fDirectional;
};

class GourandPixelShader : public render::PixelShader
{
public:
	GourandPixelShader(render::RenderTarget *target)
		:	PixelShader(target)
	{
	}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outColor[4],
		unsigned short mask) const
	{
		outColor[0] = inParams[0];
		outColor[1] = inParams[1];
		outColor[2] = inParams[2];
		outColor[3] = splatf(1.0f);
	}
};

#endif
