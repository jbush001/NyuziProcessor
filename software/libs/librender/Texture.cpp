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


#include <assert.h>
#include <math.h>
#include <stdio.h>
#include "Shader.h"
#include "Texture.h"

namespace librender
{

namespace
{

const float kOneOver255 = 1.0 / 255.0;

// Convert a 32-bit RGBA color (packed in an integer) into four floating point (0.0 - 1.0)
// color channels.
void unpackRGBA(veci16_t packedColor, vecf16_t *outColor)
{
    outColor[kColorR] = __builtin_convertvector(packedColor & 255, vecf16_t)
                        * kOneOver255;
    outColor[kColorG] = __builtin_convertvector((packedColor >> 8) & 255,
                        vecf16_t) * kOneOver255;
    outColor[kColorB] = __builtin_convertvector((packedColor >> 16) & 255,
                        vecf16_t) * kOneOver255;
    outColor[kColorA] = __builtin_convertvector((packedColor >> 24) & 255,
                        vecf16_t) * kOneOver255;
}

// Convert a number in the range -1.0 <= n <= 1.0 to 0.0 <= n < 1.0
// If the number is less than 0, add 1 so it wraps around
inline vecf16_t wrapfv(vecf16_t in)
{
    return __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_lt(in, vecf16_t(0.0)),
                                       in + vecf16_t(1.0), in);
}

// If a number is greater than max, make it be zero.
// This wraps in the case that 0 <= in <= max.
inline veci16_t wrapiv(veci16_t in, int max)
{
    return __builtin_nyuzi_vector_mixi(__builtin_nyuzi_mask_cmpf_lt(in, veci16_t(max)),
                                       in, veci16_t(0));
}

} // namespace

Texture::Texture()
{
    for (int i = 0; i < kMaxMipLevels; i++)
        fMipSurfaces[i] = nullptr;
}

void Texture::setMipSurface(int mipLevel, const Surface *surface)
{
    assert(mipLevel < kMaxMipLevels);

    fMipSurfaces[mipLevel] = surface;
    if (mipLevel > fMaxMipLevel)
        fMaxMipLevel = mipLevel;

    if (mipLevel == 0)
    {
        fBaseMipBits = __builtin_clz(static_cast<unsigned int>(surface->getWidth())) + 1;

        // Clear out lower mip levels
        for (int i = 1; i < fMaxMipLevel; i++)
            fMipSurfaces[i] = 0;

        fMaxMipLevel = 0;
    }
    else
    {
        assert(surface->getWidth() == fMipSurfaces[0]->getWidth() >> mipLevel);
    }
}

void Texture::readPixels(vecf16_t u, vecf16_t v, vmask_t mask,
                         vecf16_t *outColor) const
{
    // Determine the closest mip-level. Compute the pitch between the top
    // two pixels. The reciprocal of this is the scaled texture size. log2 of this
    // is the mip level.
    // XXX this is a hack because it only looks at one direction. Should do
    // something better here.
    int mipLevel = __builtin_clz(static_cast<unsigned int>(1.0f /
                                 __builtin_fabsf(u[1] - u[0]))) - fBaseMipBits;
    if (mipLevel > fMaxMipLevel)
        mipLevel = fMaxMipLevel;
    else if (mipLevel < 0)
        mipLevel = 0;

    const Surface *surface = fMipSurfaces[mipLevel];
    int mipWidth = surface->getWidth();
    int mipHeight = surface->getHeight();

    // Convert from texture space (0.0-1.0, 1.0-0.0) to raster coordinates
    // (0-(width - 1), 0-(height - 1)). Note that the top of the texture corresponds
    // to v of 1.0. Coordinates wrap.
    vecf16_t uRaster = wrapfv(fracfv(u)) * (mipWidth - 1);
    vecf16_t vRaster = (1.0 - wrapfv(fracfv(v))) * (mipHeight - 1);
    veci16_t tx = __builtin_convertvector(uRaster, veci16_t);
    veci16_t ty = __builtin_convertvector(vRaster, veci16_t);

    if (fEnableBilinearFiltering)
    {
        // Load four source texels that overlap the sample position
        vecf16_t tlColor[4];	// top left
        vecf16_t trColor[4];	// top right
        vecf16_t blColor[4];	// bottom left
        vecf16_t brColor[4];	// bottom right

        // These wrap around the edge of the texture
        veci16_t xPlusOne = wrapiv(tx + 1, mipWidth);
        veci16_t yPlusOne = wrapiv(ty + 1, mipHeight);

        unpackRGBA(surface->readPixels(tx, ty, mask), tlColor);
        unpackRGBA(surface->readPixels(tx, yPlusOne, mask), blColor);
        unpackRGBA(surface->readPixels(xPlusOne, ty, mask), trColor);
        unpackRGBA(surface->readPixels(xPlusOne, yPlusOne, mask), brColor);

        // Compute weights
        vecf16_t wu = fracfv(uRaster);
        vecf16_t wv = fracfv(vRaster);
        vecf16_t tlWeight = (1.0 - wu) * (1.0 - wv);
        vecf16_t trWeight = wu * (1.0 - wv);
        vecf16_t blWeight = (1.0 - wu) * wv;
        vecf16_t brWeight = wu * wv;

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
        unpackRGBA(surface->readPixels(tx, ty, mask), outColor);
    }
}

} // namespace librender


