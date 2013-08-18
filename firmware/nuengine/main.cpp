// 
// Copyright 2013 Jeff Bush
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

#include "Debug.h"
#include "RenderTarget.h"
#include "ParameterInterpolator.h"
#include "Rasterizer.h"
#include "PixelShader.h"
#include "utils.h"

const int kMaxTileIndex = (640 / 64) * ((480 / 64) + 1);
int nextTileIndex = 0;

struct Vertex
{
	float coord[3];
	float params[kMaxParams];
};

class SimpleShader : public PixelShader
{
public:
	SimpleShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outParams[16],
		unsigned short mask);
};

void SimpleShader::shadePixels(const vecf16 inParams[16], vecf16 outParams[16],
	unsigned short mask)
{
	for (int i = 0; i < 3; i++)
		outParams[i] = inParams[i];
}

const int kFbWidth = 640;
const int kFbHeight = 480;

int main()
{
	Rasterizer rasterizer;
	RenderTarget renderTarget(0x100000, kFbWidth, kFbHeight);
	ParameterInterpolator interp(kFbWidth, kFbHeight);
	SimpleShader shader(&interp, &renderTarget);

	Vertex vertices[3] = {
		{ { 0.3, 0.1, 0.4 }, { 1.0, 0.0, 0.0 } },
		{ { 0.9, 0.5, 0.4 }, { 0.0, 1.0, 0.0 } },
		{ { 0.1, 0.9, 0.4 }, { 0.0, 0.0, 1.0 } },
	};

	while (nextTileIndex < kMaxTileIndex)
	{
		int myTileIndex = __sync_fetch_and_add(&nextTileIndex, 1);
		if (myTileIndex >= kMaxTileIndex)
			break;
	
		unsigned int tileX, tileY;
		udiv(myTileIndex, 10, tileY, tileX);

		interp.setUpTriangle(
			vertices[0].coord[0], vertices[0].coord[1], vertices[0].coord[2],
			vertices[1].coord[0], vertices[1].coord[1], vertices[1].coord[2],
			vertices[2].coord[0], vertices[2].coord[1], vertices[2].coord[2]);

		for (int param = 0; param < 3; param++)
		{
			interp.setUpParam(param, vertices[0].params[param],
				vertices[1].params[param], vertices[2].params[param]);
		}

		rasterizer.rasterizeTriangle(&shader, tileX * 64, tileY * 64,
			(int)(vertices[0].coord[0] * kFbWidth), 
			(int)(vertices[0].coord[1] * kFbHeight), 
			(int)(vertices[1].coord[0] * kFbWidth), 
			(int)(vertices[1].coord[1] * kFbHeight), 
			(int)(vertices[2].coord[0] * kFbWidth), 
			(int)(vertices[2].coord[1] * kFbHeight));
	}
		
	return 0;
}

Debug Debug::debug;
