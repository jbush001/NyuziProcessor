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


#ifndef __TEXTURE_SHADER_H
#define __TEXTURE_SHADER_H

#include "VertexShader.h"
#include "PixelShader.h"

#define BILINEAR_FILTERING 1

using namespace render;

class TextureVertexShader : public render::VertexShader
{
public:
	TextureVertexShader()
		:	VertexShader(5, 6)
	{
	}

	void setProjectionMatrix(const Matrix &mat)
	{
		fProjectionMatrix = mat;
		fMVPMatrix = fProjectionMatrix * fModelViewMatrix;
	}
	
	void applyTransform(const Matrix &mat)
	{
		fModelViewMatrix = fModelViewMatrix * mat;
		fMVPMatrix = fProjectionMatrix * fModelViewMatrix;
	}

	void shadeVertices(vecf16 *outParams, const vecf16 *inAttribs, int mask) const override
	{
		// Multiply by mvp matrix
		vecf16 coord[4];
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i];
			
		coord[3] = splatf(1.0f);
		fMVPMatrix.mulVec(outParams, coord); 

		// Copy remaining parameters
		outParams[4] = inAttribs[3];
		outParams[5] = inAttribs[4];
	}
	
private:
	Matrix fMVPMatrix;
	Matrix fProjectionMatrix;
	Matrix fModelViewMatrix;
};


class TexturePixelShader : public render::PixelShader
{
public:
	TexturePixelShader(render::RenderTarget *target)
		:	PixelShader(target)
	{}
	
	void bindTexture(render::Surface *surface)
	{
		fSampler.bind(surface);
#if BILINEAR_FILTERING
		fSampler.setEnableBilinearFiltering(true);
#endif
	}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outColor[4],
		unsigned short mask) const override
	{
		fSampler.readPixels(inParams[0], inParams[1], mask, outColor);
	}
		
private:
	render::TextureSampler fSampler;
};

#endif

