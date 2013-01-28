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

#include "PrimitiveAssembly.h"
#include "Rasterizer.h"

static Rasterizer rasterizer;

void renderTriangle(int left, int top, int numParams, const Vertex *vertices, 
	PixelShaderState *shaderState, int width, int height)
{
	shaderState->setUpTriangle(
		vertices[0].coord[0], vertices[0].coord[1], vertices[0].coord[2],
		vertices[1].coord[0], vertices[1].coord[1], vertices[1].coord[2],
		vertices[2].coord[0], vertices[2].coord[1], vertices[2].coord[2]);

	for (int param = 0; param < numParams; param++)
	{
		shaderState->setUpParam(param, vertices[0].params[param],
			vertices[1].params[param], vertices[2].params[param]);
	}

	rasterizer.rasterizeTriangle(shaderState, left, top,
		(int)(vertices[0].coord[0] * width), 
		(int)(vertices[0].coord[1] * height), 
		(int)(vertices[1].coord[0] * width), 
		(int)(vertices[1].coord[1] * height), 
		(int)(vertices[2].coord[0] * width), 
		(int)(vertices[2].coord[1] * height));
}
