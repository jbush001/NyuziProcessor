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
#include "ParameterInterpolator.h"
#include "RenderTarget.h"
#include "VertexShader.h"
#include "Texture.h"
#include "DrawState.h"

namespace librender
{

enum ColorChannel
{
	kColorR,
	kColorG,
	kColorB,
	kColorA
};

//
// This is overriden by the application to perform pixel shading.
//

class PixelShader
{
public:
	virtual void shadePixels(const vecf16_t inParams[], vecf16_t outColor[4], 
		const void *uniforms, const Texture * const sampler[kMaxTextures], 
		unsigned short mask) const = 0;
};

}
