// 
// Copyright 2011-2013 Jeff Bush
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

#ifndef __PRIMITIVE_ASSEMBLY_H
#define __PRIMITIVE_ASSEMBLY_H

#include "PixelShaderState.h"

struct Vertex
{
	float coord[3];
	float params[kMaxParams];
};

void renderTriangle(int left, int top, int numParams, const Vertex *vertices, 
	PixelShaderState *shaderState, int width, int height);

#endif
