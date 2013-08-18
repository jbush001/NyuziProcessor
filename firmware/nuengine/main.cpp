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


#define COLOR_SHADER 1

const int kMaxTileIndex = (640 / 64) * ((480 / 64) + 1);
int nextTileIndex = 0;

struct Vertex
{
	float coord[3];
	float params[kMaxParams];
};

class ColorShader : public PixelShader
{
public:
	ColorShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outParams[16],
		unsigned short mask);
};

void ColorShader::shadePixels(const vecf16 inParams[16], vecf16 outParams[16],
	unsigned short mask)
{
	for (int i = 0; i < 3; i++)
		outParams[i] = inParams[i];
}

class CheckerboardShader : public PixelShader
{
public:
	CheckerboardShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outParams[16],
		unsigned short mask);
};

void CheckerboardShader::shadePixels(const vecf16 inParams[16], vecf16 outParams[16],
	unsigned short mask)
{
	veci16 u = ((__builtin_vp_vftoi(inParams[0] * __builtin_vp_makevectorf(65535.0))) 
		>> __builtin_vp_makevectori(10)) & __builtin_vp_makevectori(1);
	veci16 v = ((__builtin_vp_vftoi(inParams[1] * __builtin_vp_makevectorf(65535.0))) 
		>> __builtin_vp_makevectori(10)) & __builtin_vp_makevectori(1);

	veci16 color = u ^ v;
	
	outParams[0] = outParams[1] = outParams[2] = __builtin_vp_vitof(color);
}

const int kFbWidth = 640;
const int kFbHeight = 480;

//
// All threads start execution here
//
int main()
{
	Rasterizer rasterizer;
	RenderTarget renderTarget(0x100000, kFbWidth, kFbHeight);
	ParameterInterpolator interp(kFbWidth, kFbHeight);
#if COLOR_SHADER
	ColorShader shader(&interp, &renderTarget);
#else
	CheckerboardShader shader(&interp, &renderTarget);
#endif

	Vertex vertices[3] = {
#if COLOR_SHADER
		{ { 0.3, 0.1, 0.5 }, { 1.0, 0.0, 0.0 } },
		{ { 0.9, 0.5, 0.4 }, { 0.0, 1.0, 0.0 } },
		{ { 0.1, 0.9, 0.3 }, { 0.0, 0.0, 1.0 } },
#else
		{ { 0.3, 0.1, 0.6 }, { 0.0, 0.0 } },
		{ { 0.9, 0.5, 0.4 }, { 0.0, 1.0 } },
		{ { 0.1, 0.9, 0.1 }, { 1.0, 1.0 } },
#endif
	};

	while (nextTileIndex < kMaxTileIndex)
	{
		// Grab the next available tile to begin working on.
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

		// Fill a 64x64 tile
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
