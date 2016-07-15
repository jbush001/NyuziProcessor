//
// Copyright 2015 Jeff Bush
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

#ifndef __TEXTURE_SHADER_H
#define __TEXTURE_SHADER_H

#include <Matrix.h>
#include <Shader.h>
#include <SIMDMath.h>
#include <Texture.h>

using namespace librender;

struct TextureUniforms
{
    Matrix fMVPMatrix;
    bool enableLightmap;
    bool enableTexture;
};

enum ShaderAttribute
{
    kAttrAtlasLeft = 3,
    kAttrAtlasTop,
    kAttrAtlasWidth,
    kAttrAtlasHeight,
    kAttrTextureU,
    kAttrTextureV,
    kAttrLightmapU,
    kAttrLightmapV,
    kTotalAttrs
};

enum ShaderParam
{
    kParamAtlasLeft = 4,
    kParamAtlasTop,
    kParamAtlasWidth,
    kParamAtlasHeight,
    kParamTextureU,
    kParamTextureV,
    kParamLightmapU,
    kParamLightmapV,
    kTotalParams
};

namespace
{

// This supports repeating within the texture atlas. Low the left or top coordinate
// in the texture atlas. Span represents the height or width. value is first wrapped
// around to be 0.0-1.0, then mapped inside the coordinates of the texture entry.
inline vecf16_t wrappedAtlasCoord(vecf16_t value, vecf16_t low, vecf16_t span)
{
    vecf16_t wrappedCoord = fracfv(value);

    // Make negative values wrap around properly
    wrappedCoord = __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_lt(wrappedCoord,
                   vecf16_t(0.0)), wrappedCoord + 1.0, wrappedCoord);

    // Compute atlas coordinate
    return low + wrappedCoord * span;
}

}

class TextureShader : public Shader
{
public:
    TextureShader()
        :	Shader(kTotalAttrs, kTotalParams)
    {
    }

    void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, const void *_uniforms,
                       int) const override
    {
        const TextureUniforms *uniforms = static_cast<const TextureUniforms*>(_uniforms);

        // Multiply vertex position by mvp matrix.  X, Y, and Z are in
        // attributes, hard code W to constant 1.0.
        vecf16_t coord[4];
        for (int i = 0; i < 3; i++)
            coord[i] = inAttribs[i];

        coord[3] = 1.0f;
        uniforms->fMVPMatrix.mulVec(outParams, coord);

        // Copy other attributes
        outParams[kParamAtlasLeft] = inAttribs[kAttrAtlasLeft];
        outParams[kParamAtlasTop] = inAttribs[kAttrAtlasTop];
        outParams[kParamAtlasWidth] = inAttribs[kAttrAtlasWidth];
        outParams[kParamAtlasHeight] = inAttribs[kAttrAtlasHeight];
        outParams[kParamTextureU] = inAttribs[kAttrTextureU];
        outParams[kParamTextureV] = inAttribs[kAttrTextureV];
        outParams[kParamLightmapU] = inAttribs[kAttrLightmapU];
        outParams[kParamLightmapV] = inAttribs[kAttrLightmapV];
    }

    void shadePixels(vecf16_t *outColor, const vecf16_t *inParams,
                     const void *_castToUniforms, const Texture * const * sampler,
                     unsigned short mask) const override
    {
        TextureUniforms *uniforms = (TextureUniforms*) _castToUniforms;

        if (uniforms->enableTexture)
        {
            vecf16_t atlasU = wrappedAtlasCoord(inParams[kParamTextureU - 4], inParams[kParamAtlasLeft - 4],
                                                inParams[kParamAtlasWidth - 4]);
            vecf16_t atlasV = wrappedAtlasCoord(inParams[kParamTextureV - 4], inParams[kParamAtlasTop - 4],
                                                inParams[kParamAtlasHeight - 4]);
            sampler[0]->readPixels(atlasU, atlasV, mask, outColor);
        }
        else
        {
            outColor[0] = 1.0f;
            outColor[1] = 1.0f;
            outColor[2] = 1.0f;
            outColor[3] = 1.0f;
        }

        if (uniforms->enableLightmap)
        {
            vecf16_t lightmapValue[4];
            sampler[1]->readPixels(inParams[kParamLightmapU - 4], inParams[kParamLightmapV - 4], mask,
                                   lightmapValue);

            // We only use the lowest channel of lightmap value to represent intensity.
            vecf16_t intensity = lightmapValue[0] + 0.25;
            outColor[0] *= intensity;
            outColor[1] *= intensity;
            outColor[2] *= intensity;
        }
    }
};

#endif

