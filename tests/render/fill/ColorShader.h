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

#include <Shader.h>

using namespace librender;

class ColorShader : public Shader
{
public:
    ColorShader()
        :	Shader(3, 4)
    {
    }

    void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs, const void *,
                       int ) const override
    {
        // Position
        outParams[kParamX] = inAttribs[0];
        outParams[kParamY] = inAttribs[1];
        outParams[kParamZ] = inAttribs[2];
        outParams[kParamW] = 1.0;
    }

    void shadePixels(vecf16_t *outColor, const vecf16_t *,
                     const void *, const Texture * const *,
                     unsigned short ) const override
    {
        outColor[0] = 1.0;
        outColor[1] = 1.0;
        outColor[2] = 1.0;
        outColor[3] = 1.0;
    }
};

