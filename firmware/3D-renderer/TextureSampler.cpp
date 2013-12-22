// 
// Copyright 2BL3 Jeff Bush
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

#include "assert.h"
#include "TextureSampler.h"

using namespace render;

void extractColorChannels(veci16 packedColors, vecf16 outColor[3])
{
	outColor[0] = __builtin_vp_vitof(packedColors & splati(255))
		/ splatf(255.0f);	// B
	outColor[1] = __builtin_vp_vitof((packedColors >> splati(8)) & splati(255)) 
		/ splatf(255.0f); // G
	outColor[2] = __builtin_vp_vitof((packedColors >> splati(16)) & splati(255)) 
		/ splatf(255.0f); // R
	outColor[3] = __builtin_vp_vitof((packedColors >> splati(24)) & splati(255)) 
		/ splatf(255.0f); // A
}

TextureSampler::TextureSampler()
	:	fSurface(nullptr),
		fBilinearFilteringEnabled(false)
{
}

void TextureSampler::bind(Surface *surface)
{
	fSurface = surface;

	assert((surface->getWidth() & (surface->getWidth() - 1)) == 0);
	assert((surface->getHeight() & (surface->getHeight() - 1)) == 0);
	fWidth = surface->getWidth();
	fHeight = surface->getHeight();
}

//
// Note that this wraps by default
//
void TextureSampler::readPixels(vecf16 u, vecf16 v, unsigned short mask,
	vecf16 outColors[4])
{
	// Convert from texture space into raster coordinates
	vecf16 uRaster = u * splatf(fWidth);
	vecf16 vRaster = v * splatf(fWidth);
	

	if (fBilinearFilteringEnabled)
	{
		// Coordinate of top left texel
		veci16 tx = __builtin_vp_vftoi(uRaster) & splati(fWidth - 1);
		veci16 ty = __builtin_vp_vftoi(vRaster) & splati(fHeight - 1);

		// Load four overlapping pixels	
		vecf16 pTLColors[4];	// top left
		vecf16 pTRColors[4];	// top right
		vecf16 pBLColors[4];	// bottom left
		vecf16 pBRColors[4];	// bottom right

		extractColorChannels(fSurface->readPixels(tx, ty, mask), pTLColors);
		extractColorChannels(fSurface->readPixels(tx, (ty + splati(1)) & splati(fWidth 
			- 1), mask), pBLColors);
		extractColorChannels(fSurface->readPixels((tx + splati(1)) & splati(fWidth - 1), 
			ty, mask), pTRColors);
		extractColorChannels(fSurface->readPixels((tx + splati(1)) & splati(fWidth - 1), 
			(ty + splati(1)) & splati(fWidth - 1), mask), 
			pBRColors);

		// Compute weights
		vecf16 wx = uRaster - __builtin_vp_vitof(__builtin_vp_vftoi(uRaster));
		vecf16 wy = vRaster - __builtin_vp_vitof(__builtin_vp_vftoi(vRaster));
		vecf16 wTL = (splatf(1.0) - wy) * (splatf(1.0) - wx);
		vecf16 wTR = (splatf(1.0) - wy) * wx;
		vecf16 wBL = (splatf(1.0) - wx) * wy;
		vecf16 wBR = wx * wy;

		// Apply weights & blend
		outColors[0] = pTLColors[0] * wTL + pBLColors[0] * wBL + pTRColors[0] * wTR 
			+ pBRColors[0] * wBR;
		outColors[1] = pTLColors[1] * wTL + pBLColors[1] * wBL + pTRColors[1] * wTR 
			+ pBRColors[1] * wBR;
		outColors[2] = pTLColors[2] * wTL + pBLColors[2] * wBL + pTRColors[2] * wTR 
			+ pBRColors[2] * wBR;
		outColors[3] = pTLColors[3] * wTL + pBLColors[3] * wBL + pTRColors[3] * wTR 
			+ pBRColors[3] * wBR;
	}
	else
	{
		// Nearest neighbor
		veci16 tx = __builtin_vp_vftoi(uRaster) & splati(fWidth - 1);
		veci16 ty = __builtin_vp_vftoi(vRaster) & splati(fHeight - 1);
		extractColorChannels(fSurface->readPixels(tx, ty, mask), outColors);
	}
}

