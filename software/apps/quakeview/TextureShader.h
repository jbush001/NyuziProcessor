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
};

enum ShaderAttribute
{
	kAttrAtlasLeft = 3,
	kAttrAtlasTop,
	kAttrAtlasWidth,
	kAttrAtlasHeight,
	kAttrTextureU,
	kAttrTextureV,
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
	kTotalParams
};

namespace
{

inline vecf16_t wrappedAtlasCoord(vecf16_t value, vecf16_t low, vecf16_t span)
{
	vecf16_t wrappedCoord = fracfv(value);

	// Make negative values wrap around properly
	wrappedCoord = __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_lt(wrappedCoord, 
		splatf(0.0)), wrappedCoord + splatf(1.0), wrappedCoord);

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
			
		coord[3] = splatf(1.0f);
		uniforms->fMVPMatrix.mulVec(outParams, coord); 

		// Copy texture info
		outParams[kParamAtlasLeft] = inAttribs[kAttrAtlasLeft];
		outParams[kParamAtlasTop] = inAttribs[kAttrAtlasTop];
		outParams[kParamAtlasWidth] = inAttribs[kAttrAtlasWidth];
		outParams[kParamAtlasHeight] = inAttribs[kAttrAtlasHeight];
		outParams[kParamTextureU] = inAttribs[kAttrTextureU];
		outParams[kParamTextureV] = inAttribs[kAttrTextureV];
	}

	void shadePixels(vecf16_t outColor[4], const vecf16_t inParams[16], 
		const void *_castToUniforms, const Texture * const sampler[kMaxActiveTextures],
		unsigned short mask) const override
	{
		vecf16_t atlasU = wrappedAtlasCoord(inParams[kParamTextureU - 4], inParams[kParamAtlasLeft - 4],
			inParams[kParamAtlasWidth - 4]); 
		vecf16_t atlasV = wrappedAtlasCoord(inParams[kParamTextureV - 4], inParams[kParamAtlasTop - 4],
			inParams[kParamAtlasHeight - 4]); 
		sampler[0]->readPixels(atlasU, atlasV, mask, outColor);
	}
};

#endif

