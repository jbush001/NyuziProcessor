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


#pragma once

#include <Matrix.h>
#include <VertexShader.h>
#include <PixelShader.h>
#include <SIMDMath.h>
#include <Texture.h>

using namespace librender;

struct TextureUniforms
{
	Matrix fMVPMatrix;
	Matrix fNormalMatrix;
	bool fHasTexture;
	Vec3 fLightDirection;
	float fAmbient;
	float fDirectional;
};

class TextureVertexShader : public VertexShader
{
public:
	TextureVertexShader()
		:	VertexShader(8, 9)
	{
	}

	void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, const void *_uniforms,
        int) const override
	{
        const TextureUniforms *uniforms = static_cast<const TextureUniforms*>(_uniforms);
        
		// Multiply vertex position by mvp matrix
		vecf16_t coord[4];
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i];
			
		coord[3] = splatf(1.0f);
		uniforms->fMVPMatrix.mulVec(outParams, coord); 

		// Copy texture coordinate
		outParams[4] = inAttribs[3];
		outParams[5] = inAttribs[4];

		// Multiply normal
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i + 5];
			
		coord[3] = splatf(1.0f);
		uniforms->fNormalMatrix.mulVec(outParams + 6, coord); 
	}
};

class TexturePixelShader : public librender::PixelShader
{
public:
	void shadePixels(const vecf16_t inParams[16], vecf16_t outColor[4],
		const void *_castToUniforms, const Texture * const sampler[kMaxTextures],
		unsigned short mask) const override
	{
		const TextureUniforms *uniforms = static_cast<const TextureUniforms*>(_castToUniforms);

		// Determine lambertian illumination
		vecf16_t dot = -inParams[2] * splatf(uniforms->fLightDirection[0])
			+ -inParams[3] * splatf(uniforms->fLightDirection[1])
			+ -inParams[4] * splatf(uniforms->fLightDirection[2]);
		dot *= splatf(uniforms->fDirectional);
		vecf16_t illumination = librender::clampfv(dot) + splatf(uniforms->fAmbient);

		if (uniforms->fHasTexture)
		{
			sampler[0]->readPixels(inParams[0], inParams[1], mask, outColor);
			outColor[kColorR] *= illumination;
			outColor[kColorG] *= illumination;
			outColor[kColorB] *= illumination;
		}
		else
		{
			outColor[kColorR] = illumination;
			outColor[kColorB] = illumination;
			outColor[kColorG] = illumination;
			outColor[kColorA] = splatf(1.0);
		}
	}
};

