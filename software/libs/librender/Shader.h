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

#include <stdint.h>
#include "RenderState.h"
#include "RenderTarget.h"
#include "Texture.h"

namespace librender
{

enum ColorChannel
{
    kColorR,
    kColorG,
    kColorB,
    kColorA
};

enum VertexParam
{
    kParamX,
    kParamY,
    kParamZ,
    kParamW
};

//
// This is subclassed by the application to perform vertex and pixel shading.
//

class Shader
{
public:
    Shader(const Shader&) = delete;
    Shader& operator=(const Shader&) = delete;
    virtual ~Shader() {}

    // This is called on batches of up to 16 vertices. Attributes come in, read in
    // from RenderBuffers, and parameters are returned into outParams.
    virtual void shadeVertices(vecf16_t *outParams, const vecf16_t *inAttribs,
                               const void *uniforms, vmask_t mask) const = 0;

    // This is called on batches of up to 16 pixels, in a 4x4 grid.  Parameters
    // that were returned by shadeVertices are interpolated across the triangle
    // and passed into inParams. This should fill the colors for the pixels into
    // outColor.
    virtual void shadePixels(vecf16_t *outColor, const vecf16_t *inParams,
                             const void *uniforms, const Texture * const * sampler,
                             vmask_t mask) const = 0;

    // Number of parameters that shadeVertices returns for each vertex.
    int getNumParams() const
    {
        return fParamsPerVertex;
    }

    // Number of attributes passed to shadeVertices for each vertex.
    int getNumAttribs() const
    {
        return fAttribsPerVertex;
    }

protected:
    Shader(int attribsPerVertex, int paramsPerVertex)
        : fParamsPerVertex(paramsPerVertex),
          fAttribsPerVertex(attribsPerVertex)
    {}

private:
    int fParamsPerVertex;
    int fAttribsPerVertex;
};

} // namespace librender
