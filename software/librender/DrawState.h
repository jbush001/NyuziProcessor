// 
// Copyright (C) 2011-2015 Jeff Bush
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

#ifndef __DRAW_STATE_H
#define __DRAW_STATE_H

#include "TextureSampler.h"

namespace librender
{

const int kMaxTextureSamplers = 4;

struct DrawState
{
	bool fEnableZBuffer;
	bool fEnableBlend;
	float *fVertexParams = nullptr;
	const float *fVertices = nullptr;
	int fNumVertices;
	const int *fIndices = nullptr;
	int fNumIndices;
	const void *fUniforms = nullptr;
	int fNumVertexParams;
	const class VertexShader *fVertexShader = nullptr;	
	const class PixelShader *fPixelShader = nullptr;
	TextureSampler fTextureSamplers[kMaxTextureSamplers];
};

}

#endif
