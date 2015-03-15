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

#include "Texture.h"

namespace librender
{

const int kMaxTextures = 4;

struct DrawState
{
	bool fEnableDepthBuffer = false;
	bool fEnableBlend = false;
	const float *fVertexAttributes = nullptr;
	int fNumVertices = 0;
	const int *fIndices = nullptr;
	int fNumIndices = 0;
	const void *fUniforms = nullptr;
	int fParamsPerVertex = 0;
	float *fVertexParams = nullptr;
	const class VertexShader *fVertexShader = nullptr;	
	const class PixelShader *fPixelShader = nullptr;
	const Texture *fTextures[kMaxTextures];
	enum CullingMode
	{
		kCullCW,
		kCullCCW,
		kCullNone
	} cullingMode = kCullCW;
};

}
