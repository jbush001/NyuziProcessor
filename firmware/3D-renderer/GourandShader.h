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
	GourandVertexShader()
		:	VertexShader(6, 8)
	{
		fLightVector[0] = 0.7071067811f;
		fLightVector[1] = 0.7071067811f; 
		fLightVector[2] = 0.0f;

		fDirectional = 0.6f;		
		fAmbient = 0.2f;
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
		outParams[4] = render::clampvf(dot) + splatf(fAmbient);
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
