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

#ifndef __DEPTH_SHADER_H
#define __DEPTH_SHADER_H

#include <Matrix.h>
#include <Shader.h>

using namespace librender;

struct ShadowMapUniforms
{
    Matrix fMVPMatrix;
};

// Represents depth as a brightness
class ShadowMapShader : public Shader
{
public:
    ShadowMapShader()
        :	Shader(8, 5)
    {
    }

    void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, const void *_uniforms,
                       vmask_t) const override
    {
        const ShadowMapUniforms *uniforms = static_cast<const ShadowMapUniforms*>(_uniforms);

        // Multiply vertex position by mvp matrix
        vecf16_t coord[4];
        for (int i = 0; i < 3; i++)
            coord[i] = inAttribs[i];

        coord[3] = 1.0f;
        uniforms->fMVPMatrix.mulVec(outParams, coord);

        // Copy depth
        outParams[4] = outParams[2];
    }

    void shadePixels(vecf16_t *outColor, const vecf16_t *inParams,
                     const void *, const Texture * const * ,
                     vmask_t) const override
    {
        outColor[0] = inParams[0];  // Copy depth value
    }
};

#endif
