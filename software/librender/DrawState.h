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

#include "Texture.h"

namespace librender
{

const int kMaxTextures = 4;

struct DrawState
{
	bool fEnableZBuffer = false;
	bool fEnableBlend = false;
	const float *fVertexAttributes = nullptr;
	int fNumVertices = 0;
	const int *fIndices = nullptr;
	int fNumIndices = 0;
	const void *fUniforms = nullptr;
	int fParamsPerVertex = 0;
	float *fVertexParams = nullptr;
	const class VertexShader *fVertexShader = nullptr;	
	const class PixelShader *fPixelShader = nullptr;
	const Texture *fTextures[kMaxTextures];
	enum CullingMode
	{
		kCullCW,
		kCullCCW,
		kCullNone
	} cullingMode = kCullCW;
};

}

#endif
