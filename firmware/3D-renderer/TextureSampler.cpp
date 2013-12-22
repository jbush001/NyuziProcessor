// 
// Copyright 2013 Jeff Bush
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
		// Compute weights
		vecf16 wx = uRaster - __builtin_vp_vitof(__builtin_vp_vftoi(uRaster));
		vecf16 wy = vRaster - __builtin_vp_vitof(__builtin_vp_vftoi(vRaster));
		vecf16 w11 = wx * wy;
		vecf16 w01 = (splatf(1.0) - wx) * wy;
		vecf16 w10 = (splatf(1.0) - wy) * wx;
		vecf16 w00 = (splatf(1.0) - wy) * (splatf(1.0) - wx);

		// Load pixels	
		vecf16 p00Colors[4];
		vecf16 p10Colors[4];
		vecf16 p01Colors[4];
		vecf16 p11Colors[4];

		veci16 tx = __builtin_vp_vftoi(uRaster) & splati(fWidth - 1);
		veci16 ty = __builtin_vp_vftoi(vRaster) & splati(fHeight - 1);

		extractColorChannels(fSurface->readPixels(tx, ty, mask), p00Colors);
		extractColorChannels(fSurface->readPixels(tx, (ty + splati(1)) & splati(fWidth 
			- 1), mask), p01Colors);
		extractColorChannels(fSurface->readPixels((tx + splati(1)) & splati(fWidth - 1), 
			ty, mask), p10Colors);
		extractColorChannels(fSurface->readPixels((tx + splati(1)) & splati(fWidth - 1), 
			(ty + splati(1)) & splati(fWidth - 1), mask), 
			p11Colors);

		// Apply weights & blend
		outColors[0] = p00Colors[0] * w00 + p01Colors[0] * w01 + p10Colors[0] * w10 
			+ p11Colors[0] * w11;
		outColors[1] = p00Colors[1] * w00 + p01Colors[1] * w01 + p10Colors[1] * w10 
			+ p11Colors[1] * w11;
		outColors[2] = p00Colors[2] * w00 + p01Colors[2] * w01 + p10Colors[2] * w10 
			+ p11Colors[2] * w11;
		outColors[3] = p00Colors[3] * w00 + p01Colors[3] * w01 + p10Colors[3] * w10 
			+ p11Colors[3] * w11;
	}
	else
	{
		// Nearest neighbor
		veci16 tx = __builtin_vp_vftoi(uRaster) & splati(fWidth - 1);
		veci16 ty = __builtin_vp_vftoi(vRaster) & splati(fHeight - 1);
		extractColorChannels(fSurface->readPixels(tx, ty, mask), outColors);
	}
}

