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

#define TOON_SHADING 0

#include <Shader.h>
#include <SIMDMath.h>

using namespace librender;

struct PhongUniforms
{
    Matrix fMVPMatrix;
    Matrix fNormalMatrix;
    float fLightVector[3];
    float fAmbient;
    float fDirectional;
};

//
// The Phong shader interpolates  normals across the surface of the triangle
// and computes the dot product at each pixel
//
class PhongShader : public Shader
{
public:
    PhongShader()
        :	Shader(6, 8)
    {
    }

    void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, const void *_uniforms,
                       int ) const override
    {
        const PhongUniforms *uniforms = static_cast<const PhongUniforms*>(_uniforms);

        // Multiply by mvp matrix
        vecf16_t coord[4];
        for (int i = 0; i < 3; i++)
            coord[i] = inAttribs[i];

        coord[3] = 1.0f;
        uniforms->fMVPMatrix.mulVec(outParams, coord);

        for (int i = 0; i < 3; i++)
            coord[i] = inAttribs[i + 3];

        coord[3] = 1.0f;

        uniforms->fNormalMatrix.mulVec(outParams + 4, coord);
    }

    void shadePixels(vecf16_t *outColor, const vecf16_t *inParams,
                     const void *_castToUniforms, const Texture * const *,
                     unsigned short ) const override
    {
        const PhongUniforms *uniforms = static_cast<const PhongUniforms*>(_castToUniforms);

        // Normalize surface normal.
        vecf16_t nx = inParams[0];
        vecf16_t ny = inParams[1];
        vecf16_t nz = inParams[2];
        vecf16_t invmag = isqrtfv(nx * nx + ny * ny + nz * nz);
        nx *= invmag;
        ny *= invmag;
        nz *= invmag;

        // Dot product determines lambertian reflection
        vecf16_t dot = -nx * uniforms->fLightVector[0]
                       + -ny * uniforms->fLightVector[1]
                       + -nz * uniforms->fLightVector[2];
        dot *= uniforms->fDirectional;
#if TOON_SHADING
        // Default
        outColor[kColorR] = 0.2f;
        outColor[kColorG] = 0.1f;
        outColor[kColorB] = 0.1f;

        int cmp = __builtin_nyuzi_mask_cmpf_gt(dot, 0.25f);
        outColor[kColorR] = __builtin_nyuzi_vector_mixf(cmp, 0.4f, outColor[kColorR]);
        outColor[kColorG] = __builtin_nyuzi_vector_mixf(cmp, 0.2f, outColor[kColorG]);
        outColor[kColorB] = __builtin_nyuzi_vector_mixf(cmp, 0.2f, outColor[kColorB]);

        cmp = __builtin_nyuzi_mask_cmpf_gt(dot, 0.5f);
        outColor[kColorR] = __builtin_nyuzi_vector_mixf(cmp, 0.6f, outColor[kColorR]);
        outColor[kColorG] = __builtin_nyuzi_vector_mixf(cmp, 0.3f, outColor[kColorG]);
        outColor[kColorB] = __builtin_nyuzi_vector_mixf(cmp, 0.3f, outColor[kColorB]);

        cmp = __builtin_nyuzi_mask_cmpf_gt(dot, 0.95f);
        outColor[kColorR] = __builtin_nyuzi_vector_mixf(cmp, 1.0f, outColor[kColorR]);
        outColor[kColorG] = __builtin_nyuzi_vector_mixf(cmp, 0.5f, outColor[kColorG]);
        outColor[kColorB] = __builtin_nyuzi_vector_mixf(cmp, 0.5f, outColor[kColorB]);
#else
        outColor[kColorR] = librender::clamp(dot, 0.0, 1.0) + uniforms->fAmbient;
        outColor[kColorG] = outColor[kColorB] = 0.0f;
#endif
        outColor[3] = 1.0f;	// Alpha
    }
};
