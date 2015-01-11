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


#ifndef __SHADER_FILLER_H
#define __SHADER_FILLER_H

#include <stdint.h>
#include "DrawState.h"
#include "ParameterInterpolator.h"
#include "RenderTarget.h"
#include "PixelShader.h"
#include "VertexShader.h"

namespace librender
{

// This is called by the rasterizer for each batch of pixels. It will compute
// the colors for them by calling into the shader, then write them back to the
// appropriate render target.
// Because this contains vector elements, it must be allocated on a cache boundary
class ShaderFiller
{
public:
	ShaderFiller(const DrawState *state, RenderTarget *target);

	// Called by rasterizer to fill a 4x4 block
	void fillMasked(int left, int top, unsigned short mask);

	void setUpTriangle(float x1, float y1, float z1, 
		float x2, float y2, float z2,
		float x3, float y3, float z3)
	{
		fInterpolator.setUpTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3);
	}

	void setUpParam(int paramIndex, float c1, float c2, float c3)
	{
		fInterpolator.setUpParam(paramIndex, c1, c2, c3);
	}

private:
	vecf16_t fXStep;
	vecf16_t fYStep;
	const DrawState *fState;
	RenderTarget *fTarget;
	ParameterInterpolator fInterpolator;
	float fTwoOverWidth;
	float fTwoOverHeight;
};

}

#endif
