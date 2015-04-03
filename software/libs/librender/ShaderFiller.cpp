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

ShaderFiller::ShaderFiller(const RenderState *state, RenderTarget *target)
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

// The triangle parameters are set up in world coordinate space, but the interpolant
// values will be requested in screen space. In order for them to be perspective correct,
// use the approach described in the paper "Perspective-Correct Interpolation" 
// by Kok-Lim Low:
// "the attribute value at point c in the image plane can be correctly derived by 
// just linearly interpolating between I1/Z1 and I2/Z2, and then divide the 
// interpolated result by 1/Zt, which itself can be derived by linear interpolation"

void ShaderFiller::setUpTriangle(float x0, float y0, float z0, 
	float x1, float y1, float z1,
	float x2, float y2, float z2)
{
	fX0 = x0;
	fY0 = y0;
	fZ0 = z0;
	fZ1 = z1;
	fZ2 = z2;
	
	// We can express the deltas of any parameter as the 
	// following system of equations, where gX and gY 
	// represent the change of the parameter for changes
	// in X and Y. and c_n represents the parameter at each
	// point:
	// | a b | | gX | = | c1 - c0 |
	// | c d | | gY |   | c2 - c0 |
	float a = x1 - x0;
	float b = y1 - y0;
	float c = x2 - x0;
	float d = y2 - y0;
	
	// Invert the matrix so we can find the gradients given
	// the coefficients.
	float oneOverDeterminant = 1.0 / (a * d - b * c);
	fA00 = d * oneOverDeterminant;
	fA10 = -c * oneOverDeterminant;
	fA01 = -b * oneOverDeterminant;
	fA11 = a * oneOverDeterminant;

	// Compute one over Z for interpolation.
	fOneOverZInterpolator.init(fA00, fA01, fA10, fA11, fX0, fY0, 1.0f / z0, 
		1.0f / z1, 1.0f / z2);
	fNumParams = 0;
}

// c1, c2, and c2 represent the value of the parameter at the three
// triangle points specified in setUpTriangle.  These must be divided by
// Z to be perspective correct, as described above.
void ShaderFiller::setUpParam(float c0, float c1, float c2)
{
	fParamOverZInterpolator[fNumParams++].init(fA00, fA01, fA10, fA11, 
		fX0, fY0, c0 / fZ0, c1 / fZ1, c2 / fZ2);
}

void ShaderFiller::fillMasked(int left, int top, unsigned short mask)
{
	// Convert from raster to screen space coordinates.
	vecf16_t x = fXStep + splatf(left * fTwoOverWidth - 1.0f);
	vecf16_t y = splatf(1.0f - top * fTwoOverHeight) - fYStep;

	// Depth buffer
	vecf16_t zValues = splatf(1.0f) / fOneOverZInterpolator.getValuesAt(x, y);
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

	// Interpolate parameters
	vecf16_t interpolatedParams[kMaxParams];
	for (int i = 0; i < fNumParams; i++)
		interpolatedParams[i] = fParamOverZInterpolator[i].getValuesAt(x, y) * zValues;

	// Shade
	vecf16_t color[4];
	fState->fPixelShader->shadePixels(interpolatedParams, color, fState->fUniforms, fState->fTextures, 
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

