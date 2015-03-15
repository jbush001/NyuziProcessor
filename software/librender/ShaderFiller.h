// 
// Copyright 2011-2015 Jeff Bush
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


#pragma once

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

	void setUpParam(float c1, float c2, float c3)
	{
		fInterpolator.setUpParam(c1, c2, c3);
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
