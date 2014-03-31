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

// Convert a 32-bit BGRA color (packed in an integer) into four floating point (0.0 - 1.0) color channels.
static void extractColorChannels(veci16 packedColor, vecf16 outColor[3])
{
	outColor[0] = __builtin_vp_vitof(packedColor & splati(255))
		/ splatf(255.0f);	// B
	outColor[1] = __builtin_vp_vitof((packedColor >> splati(8)) & splati(255)) 
		/ splatf(255.0f); // G
	outColor[2] = __builtin_vp_vitof((packedColor >> splati(16)) & splati(255)) 
		/ splatf(255.0f); // R
	outColor[3] = __builtin_vp_vitof((packedColor >> splati(24)) & splati(255)) 
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
	vecf16 outColor[4]) const
{
	// Convert from texture space (0.0-1.0, 0.0-1.0) to raster coordinates 
	// (0-(width - 1), 0-(height - 1))
	vecf16 uRaster = u * splatf(fWidth);
	vecf16 vRaster = v * splatf(fWidth);

	if (fBilinearFilteringEnabled)
	{
		// Coordinate of top left texel
		veci16 tx = __builtin_vp_vftoi(uRaster) & splati(fWidth - 1);
		veci16 ty = __builtin_vp_vftoi(vRaster) & splati(fHeight - 1);

		// Load four overlapping pixels	
		vecf16 tlColor[4];	// top left
		vecf16 trColor[4];	// top right
		vecf16 blColor[4];	// bottom left
		vecf16 brColor[4];	// bottom right

		extractColorChannels(fSurface->readPixels(tx, ty, mask), tlColor);
		extractColorChannels(fSurface->readPixels(tx, (ty + splati(1)) & splati(fWidth 
			- 1), mask), blColor);
		extractColorChannels(fSurface->readPixels((tx + splati(1)) & splati(fWidth - 1), 
			ty, mask), trColor);
		extractColorChannels(fSurface->readPixels((tx + splati(1)) & splati(fWidth - 1), 
			(ty + splati(1)) & splati(fWidth - 1), mask), brColor);

		// Compute weights
		vecf16 wx = uRaster - __builtin_vp_vitof(__builtin_vp_vftoi(uRaster));
		vecf16 wy = vRaster - __builtin_vp_vitof(__builtin_vp_vftoi(vRaster));
		vecf16 tlWeight = (splatf(1.0) - wy) * (splatf(1.0) - wx);
		vecf16 trWeight = (splatf(1.0) - wy) * wx;
		vecf16 blWeight = (splatf(1.0) - wx) * wy;
		vecf16 brWeight = wx * wy;

		// Apply weights & blend
		for (int channel = 0; channel < 4; channel++)
		{
			outColor[channel] = (tlColor[channel] * tlWeight) 
				+ (blColor[channel] * blWeight)
				+ (trColor[channel] * trWeight) 
				+ (brColor[channel] * brWeight);
		}
	}
	else
	{
		// Nearest neighbor
		veci16 tx = __builtin_vp_vftoi(uRaster) & splati(fWidth - 1);
		veci16 ty = __builtin_vp_vftoi(vRaster) & splati(fHeight - 1);
		extractColorChannels(fSurface->readPixels(tx, ty, mask), outColor);
	}
}

