//
// Copyright 2017 Jeff Bush
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

#include <Shader.h>
#include <SIMDMath.h>

using namespace librender;

const float kShadowBias = 0.2;

#define ENABLE_SHADOW 1
#define USE_LAMBERTIAN 1

struct OutputUniforms
{
    Matrix fMVPMatrix;
    Matrix fNormalMatrix;
    Vec3 fLightVector;
    float fAmbient;
    float fDirectional;
    Matrix fLightMatrix;
};

//
// The Output shader interpolates  normals across the surface of the triangle
// and computes the dot product at each pixel
//
class OutputShader : public Shader
{
public:
    OutputShader()
        :	Shader(6, 12)
    {
    }

    void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, const void *_uniforms,
                       vmask_t) const override
    {
        const OutputUniforms *uniforms = static_cast<const OutputUniforms*>(_uniforms);

        // Multiply by mvp matrix
        vecf16_t coord[4];
        for (int i = 0; i < 3; i++)
            coord[i] = inAttribs[i];

        coord[3] = 1.0f;
        uniforms->fMVPMatrix.mulVec(outParams, coord);
        uniforms->fLightMatrix.mulVec(outParams + 8, coord);

        // Transform normal
        for (int i = 0; i < 3; i++)
            coord[i] = inAttribs[i + 3];

        coord[3] = 1.0f;
        uniforms->fNormalMatrix.mulVec(outParams + 4, coord);
    }

    void shadePixels(vecf16_t *outColor, const vecf16_t *inParams,
                     const void *_castToUniforms, const Texture * const *sampler,
                     vmask_t mask) const override
    {
#if USE_LAMBERTIAN
        const OutputUniforms *uniforms = static_cast<const OutputUniforms*>(_castToUniforms);

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
        vecf16_t reflection = librender::clamp(dot, 0.0, 1.0) + uniforms->fAmbient;
#else
        (void) _castToUniforms;
        vecf16_t reflection = 1.0;
#endif

        vecf16_t shadowMapValue[4];
        sampler[0]->readPixels(inParams[4] * 0.5 + 0.5, inParams[5] * 0.5 + 0.5, mask,
            shadowMapValue);
#if ENABLE_SHADOW
        // The multiplier here must be the inverse of the one in
        // ShadowMapShader.
        vecf16_t depth = -shadowMapValue[0] * 10;
        vmask_t inShadow = __builtin_nyuzi_mask_cmpf_gt(depth - inParams[6],
            (vecf16_t) kShadowBias);
#else
        vmask_t inShadow = 0;
#endif
        vecf16_t colorVal = __builtin_nyuzi_vector_mixf(inShadow,
            reflection * 0.25, reflection);
        outColor[kColorR] = colorVal;
        outColor[kColorG] = colorVal;
        outColor[kColorB] = colorVal;
        outColor[kColorA] = 1.0f;
    }
};
