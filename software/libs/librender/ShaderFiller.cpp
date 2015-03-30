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


#include <stdio.h>
#include "ShaderFiller.h"

using namespace librender;

ShaderFiller::ShaderFiller(const DrawState *state, RenderTarget *target)
	: 	fState(state),
		fTarget(target),
		fTwoOverWidth(2.0f / target->getColorBuffer()->getWidth()),
		fTwoOverHeight(2.0f / target->getColorBuffer()->getHeight())
{
	float width = target->getColorBuffer()->getWidth();
	float height = target->getColorBuffer()->getHeight();
	
	for (int x = 0; x < 4; x++)
	{
		for (int y = 0; y < 4; y++)
		{
			fXStep[y * 4 + x] = 2.0f * float(x) / width;
			fYStep[y * 4 + x] = 2.0f * float(y) / height;
		}
	}
}

void ShaderFiller::fillMasked(int left, int top, unsigned short mask)
{
	vecf16_t color[4];
	vecf16_t inParams[kMaxParams];
	vecf16_t zValues;
	vecf16_t x = fXStep + splatf(left * fTwoOverWidth - 1.0f);
	vecf16_t y = splatf(1.0f - top * fTwoOverHeight) - fYStep;
	fInterpolator.computeParams(x, y, inParams, zValues);

	if (fState->fEnableDepthBuffer)
	{
		vecf16_t depthBufferValues = (vecf16_t) fTarget->getDepthBuffer()->readBlock(left, top);
		int passDepthTest = __builtin_nyuzi_mask_cmpf_gt(zValues, depthBufferValues);

		// Early Z optimization: any pixels that fail the Z test are removed
		// from the pixel mask.
		mask &= passDepthTest;
		if (!mask)
			return;	// All pixels are occluded

		fTarget->getDepthBuffer()->writeBlockMasked(left, top, mask, zValues);
	}

	fState->fPixelShader->shadePixels(inParams, color, fState->fUniforms, fState->fTextures, 
		mask);

	veci16_t rS = __builtin_convertvector(clampfv(color[kColorR]) * splatf(255.0f), veci16_t);
	veci16_t gS = __builtin_convertvector(clampfv(color[kColorG]) * splatf(255.0f), veci16_t);
	veci16_t bS = __builtin_convertvector(clampfv(color[kColorB]) * splatf(255.0f), veci16_t);
	
	veci16_t pixelValues;

	// If all pixels are fully opaque, don't bother trying to blend them.
	if (fState->fEnableBlend
		&& (__builtin_nyuzi_mask_cmpf_lt(color[kColorA], splatf(1.0f)) & mask) != 0)
	{
		veci16_t aS = __builtin_convertvector(clampfv(color[kColorA]) * splatf(255.0f), veci16_t) 
			& splati(0xff);
		veci16_t oneMinusAS = splati(255) - aS;
	
		veci16_t destColors = fTarget->getColorBuffer()->readBlock(left, top);
		veci16_t rD = destColors & splati(0xff);
		veci16_t gD = (destColors >> splati(8)) & splati(0xff);
		veci16_t bD = (destColors >> splati(16)) & splati(0xff);

		// Premultiplied alpha
		veci16_t newR = saturateiv<255>(((rS << splati(8)) + (rD * oneMinusAS)) >> splati(8));
		veci16_t newG = saturateiv<255>(((gS << splati(8)) + (gD * oneMinusAS)) >> splati(8));
		veci16_t newB = saturateiv<255>(((bS << splati(8)) + (bD * oneMinusAS)) >> splati(8));
		pixelValues = splati(0xff000000) | newR | (newG << splati(8)) | (newB << splati(16));
	}
	else
		pixelValues = splati(0xff000000) | rS | (gS << splati(8)) | (bS << splati(16));

	fTarget->getColorBuffer()->writeBlockMasked(left, top, mask, pixelValues);
}

