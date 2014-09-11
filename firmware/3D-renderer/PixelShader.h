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


#ifndef __PIXEL_SHADER_H
#define __PIXEL_SHADER_H

#include "ParameterInterpolator.h"
#include "RenderTarget.h"
#include "VertexShader.h"

namespace render
{

class PixelShader
{
public:
	PixelShader(RenderTarget *target);
	void setUpTriangle(float x1, float y1, float z1, 
		float x2, float y2, float z2,
		float x3, float y3, float z3);
	void setUpParam(int paramIndex, float c1, float c2, float c3);

	void fillMasked(int left, int top, unsigned short mask) const;
	void enableZBuffer(bool enabled)
	{
		fEnableZBuffer = enabled;
	}
	
	bool isZBufferEnabled() const
	{
		return fEnableZBuffer;
	}
	
	void enableBlend(bool enabled)
	{
		fEnableBlend = enabled;
	}
	
	bool isBlendEnabled() const
	{
		return fEnableBlend;
	}
	
	virtual void shadePixels(const vecf16 inParams[kMaxVertexParams], 
		vecf16 outColor[4], unsigned short mask) const = 0;
private:
	RenderTarget *fTarget;
	ParameterInterpolator fInterpolator;
	float fTwoOverWidth;
	float fTwoOverHeight;
	bool fEnableZBuffer;
	bool fEnableBlend;
};

}

#endif
