// 
// Copyright 2011-2013 Jeff Bush
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

#include "PixelShader.h"
#include "Debug.h"

using namespace render;

PixelShader::PixelShader(RenderTarget *target)
	: 	fTarget(target),
		fInterpolator(target->getColorBuffer()->getWidth(), target->getColorBuffer()->getHeight()),
		fTwoOverWidth(2.0f / target->getColorBuffer()->getWidth()),
		fTwoOverHeight(2.0f / target->getColorBuffer()->getHeight()),
		fEnableZBuffer(false),
		fEnableBlend(false)
{
}

void PixelShader::setUpTriangle(float x1, float y1, float z1, 
	float x2, float y2, float z2,
	float x3, float y3, float z3)
{
	fInterpolator.setUpTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3);
}

void PixelShader::setUpParam(int paramIndex, float c1, float c2, float c3)
{
	fInterpolator.setUpParam(paramIndex, c1, c2, c3);
}

void PixelShader::fillMasked(int left, int top, unsigned short mask) const
{
	vecf16 outParams[4];
	vecf16 inParams[kMaxParams];
	vecf16 zValues;

	fInterpolator.computeParams(left * fTwoOverWidth - 1.0f, top * fTwoOverHeight
		- 1.0f, inParams, zValues);

	if (isZBufferEnabled())
	{
		vecf16 depthBufferValues = (vecf16) fTarget->getZBuffer()->readBlock(left, top);
		int passDepthTest = __builtin_vp_mask_cmpf_lt(zValues, depthBufferValues);

		// Early Z optimization: any pixels that fail the Z test are removed
		// from the pixel mask.
		mask &= passDepthTest;
		if (!mask)
			return;	// All pixels are occluded

		fTarget->getZBuffer()->writeBlockMasked(left, top, mask, zValues);
	}

	shadePixels(inParams, outParams, mask);

	// outParams 0, 1, 2, 3 are r, g, b, and a of an output pixel
	veci16 rS = __builtin_vp_vftoi(clampvf(outParams[0]) * splatf(255.0f));
	veci16 gS = __builtin_vp_vftoi(clampvf(outParams[1]) * splatf(255.0f));
	veci16 bS = __builtin_vp_vftoi(clampvf(outParams[2]) * splatf(255.0f));
	
	veci16 pixelValues;

	// Early alpha check is also performed here.  If all pixels are fully opaque,
	// don't bother trying to blend them.
	if (isBlendEnabled()
		&& (__builtin_vp_mask_cmpf_lt(outParams[3], splatf(1.0f)) & mask) != 0)
	{
		veci16 aS = __builtin_vp_vftoi(clampvf(outParams[3]) * splatf(255.0f)) & splati(0xff);
		veci16 oneMinusAS = splati(255) - aS;
	
		veci16 destColors = fTarget->getColorBuffer()->readBlock(left, top);
		veci16 rD = (destColors >> splati(16)) & splati(0xff);
		veci16 gD = (destColors >> splati(8)) & splati(0xff);
		veci16 bD = destColors & splati(0xff);

		veci16 newR = ((rS * aS) + (rD * oneMinusAS)) >> splati(8);
		veci16 newG = ((gS * aS) + (gD * oneMinusAS)) >> splati(8);
		veci16 newB = ((bS * aS) + (bD * oneMinusAS)) >> splati(8);
		pixelValues = newB | (newG << splati(8)) | (newR << splati(16));
	}
	else
		pixelValues = bS | (gS << splati(8)) | (rS << splati(16));

	fTarget->getColorBuffer()->writeBlockMasked(left, top, mask, pixelValues);
}

