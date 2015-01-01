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

#include <stdio.h>
#include "ShaderFiller.h"

using namespace librender;

ShaderFiller::ShaderFiller(RenderTarget *target)
	: 	fInterpolator(target->getColorBuffer()->getWidth(), target->getColorBuffer()->getHeight()),
		fTarget(target)
{
}

void ShaderFiller::fillMasked(int left, int top, unsigned short mask)
{
	vecf16_t outParams[4];
	vecf16_t inParams[kMaxParams];
	vecf16_t zValues;

	fInterpolator.computeParams(left, top, inParams, zValues);

	if (fEnableZBuffer)
	{
		vecf16_t depthBufferValues = (vecf16_t) fTarget->getZBuffer()->readBlock(left, top);
		int passDepthTest = __builtin_nyuzi_mask_cmpf_lt(zValues, depthBufferValues);

		// Early Z optimization: any pixels that fail the Z test are removed
		// from the pixel mask.
		mask &= passDepthTest;
		if (!mask)
			return;	// All pixels are occluded

		fTarget->getZBuffer()->writeBlockMasked(left, top, mask, zValues);
	}

	fPixelShader->shadePixels(inParams, outParams, fUniforms, mask);

	// outParams 0, 1, 2, 3 are r, g, b, and a of an output pixel
	veci16_t rS = __builtin_nyuzi_vftoi(clampfv(outParams[kColorR]) * splatf(255.0f));
	veci16_t gS = __builtin_nyuzi_vftoi(clampfv(outParams[kColorG]) * splatf(255.0f));
	veci16_t bS = __builtin_nyuzi_vftoi(clampfv(outParams[kColorB]) * splatf(255.0f));
	
	veci16_t pixelValues;

	// If all pixels are fully opaque, don't bother trying to blend them.
	if (fEnableBlend
		&& (__builtin_nyuzi_mask_cmpf_lt(outParams[kColorA], splatf(1.0f)) & mask) != 0)
	{
		veci16_t aS = __builtin_nyuzi_vftoi(clampfv(outParams[kColorA]) * splatf(255.0f)) & splati(0xff);
		veci16_t oneMinusAS = splati(255) - aS;
	
		veci16_t destColors = fTarget->getColorBuffer()->readBlock(left, top);
		veci16_t rD = destColors & splati(0xff);
		veci16_t gD = (destColors >> splati(8)) & splati(0xff);
		veci16_t bD = (destColors >> splati(16)) & splati(0xff);

		veci16_t newR = ((rS * aS) + (rD * oneMinusAS)) >> splati(8);
		veci16_t newG = ((gS * aS) + (gD * oneMinusAS)) >> splati(8);
		veci16_t newB = ((bS * aS) + (bD * oneMinusAS)) >> splati(8);
		pixelValues = splati(0xff000000) | newR | (newG << splati(8)) | (newB << splati(16));
	}
	else
		pixelValues = splati(0xff000000) | rS | (gS << splati(8)) | (bS << splati(16));

	fTarget->getColorBuffer()->writeBlockMasked(left, top, mask, pixelValues);
}

