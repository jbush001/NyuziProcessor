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


#ifndef __COLOR_SHADER
#define __COLOR_SHADER

#include <VertexShader.h>
#include <PixelShader.h>

using namespace librender;

class ColorVertexShader : public librender::VertexShader
{
public:
	ColorVertexShader()
		:	VertexShader(3, 4)
	{
	}

	void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, const void *,
        int ) const override
	{
		// Position
		outParams[kParamX] = inAttribs[0];
		outParams[kParamY] = inAttribs[1];
		outParams[kParamZ] = inAttribs[2];
		outParams[kParamW] = splatf(1.0);
	}
};

class ColorPixelShader : public librender::PixelShader
{
public:
	void shadePixels(const vecf16_t [16], vecf16_t outColor[4],
		const void *, const Texture * const [kMaxTextures],
		unsigned short ) const override
	{
		outColor[0] = splatf(1.0);
		outColor[1] = splatf(1.0);
		outColor[2] = splatf(1.0);
		outColor[3] = splatf(1.0);
	}
};

#endif
