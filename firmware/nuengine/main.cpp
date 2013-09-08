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

#include "assert.h"
#include "Debug.h"
#include "RenderTarget.h"
#include "ParameterInterpolator.h"
#include "Rasterizer.h"
#include "PixelShader.h"
#include "TextureSampler.h"
#include "utils.h"

#define COLOR_SHADER 0
#define TEXTURE_SHADER 1

const int kMaxTileIndex = (640 / 64) * ((480 / 64) + 1);
int nextTileIndex = 0;
extern char *kImage;

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
	unsigned short /* mask */)
{
	for (int i = 0; i < 3; i++)
		outParams[i] = inParams[i];

	outParams[3] = __builtin_vp_makevectorf(0.7f);
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
	unsigned short /* mask */)
{
	veci16 u = ((__builtin_vp_vftoi(inParams[0] * __builtin_vp_makevectorf(65535.0))) 
		>> __builtin_vp_makevectori(10)) & __builtin_vp_makevectori(1);
	veci16 v = ((__builtin_vp_vftoi(inParams[1] * __builtin_vp_makevectorf(65535.0))) 
		>> __builtin_vp_makevectori(10)) & __builtin_vp_makevectori(1);

	veci16 color = u ^ v;
	
	outParams[0] = outParams[1] = outParams[2] = __builtin_vp_vitof(color);
	outParams[3] = __builtin_vp_makevectorf(0.7f);
}

class TextureShader : public PixelShader
{
public:
	TextureShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{}
	
	void bindTexture(Surface *surface)
	{
		fSampler.bind(surface);
	}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outParams[16],
		unsigned short mask);
		
private:
	TextureSampler fSampler;
};

void TextureShader::shadePixels(const vecf16 inParams[16], vecf16 outParams[16],
	unsigned short mask)
{
	veci16 values = fSampler.readPixels(inParams[0], inParams[1]);

	outParams[2] = __builtin_vp_vitof((values >> __builtin_vp_makevectori(16)) 
		& __builtin_vp_makevectori(255)) / __builtin_vp_makevectorf(255.0f); // R
	outParams[1] = __builtin_vp_vitof((values >> __builtin_vp_makevectori(8)) 
		& __builtin_vp_makevectori(255)) / __builtin_vp_makevectorf(255.0f); // G
	outParams[0] = __builtin_vp_vitof(values & __builtin_vp_makevectori(255))
		/ __builtin_vp_makevectorf(255.0f);	// B
	outParams[3] = __builtin_vp_vitof((values >> __builtin_vp_makevectori(24)) 
		& __builtin_vp_makevectori(255)) / __builtin_vp_makevectorf(255.0f); // A
}

const int kFbWidth = 640;
const int kFbHeight = 480;

// Hard-coded for now.  This normally would be generated during the geometry phase...
Vertex gVertices[] = {
#if TEXTURE_SHADER
	{ { 0.3, 0.1, 0.6 }, { 0.0, 0.0 } },
	{ { 0.9, 0.5, 0.4 }, { 1.0, 0.0 } },
	{ { 0.1, 0.9, 0.1 }, { 0.0, 1.0 } },
#elif COLOR_SHADER
	{ { 0.3, 0.1, 0.6 }, { 1.0, 0.0, 0.0 } },
	{ { 0.9, 0.5, 0.4 }, { 0.0, 1.0, 0.0 } },
	{ { 0.1, 0.9, 0.1 }, { 0.0, 0.0, 1.0 } },

	{ { 0.3, 0.9, 0.3 }, { 1.0, 1.0, 0.0 } },
	{ { 0.5, 0.1, 0.3 }, { 0.0, 1.0, 1.0 } },
	{ { 0.8, 0.8, 0.3 }, { 1.0, 0.0, 1.0 } },
#else
	{ { 0.3, 0.1, 0.6 }, { 0.0, 0.0 } },
	{ { 0.9, 0.5, 0.4 }, { 0.0, 1.0 } },
	{ { 0.1, 0.9, 0.1 }, { 1.0, 1.0 } },

	{ { 0.3, 0.9, 0.3 }, { 1.0, 1.0 } },
	{ { 0.5, 0.1, 0.3 }, { 0.0, 1.0 } },
	{ { 0.8, 0.8, 0.3 }, { 1.0, 0.0 } },
#endif
};

#if COLOR_SHADER
int gNumVertexParams = 3;
#else
int gNumVertexParams = 2;
#endif

#if TEXTURE_SHADER
int gNumVertices = 3;
#else
int gNumVertices = 6;
#endif

//
// All threads start execution here
//
int main()
{
	Rasterizer rasterizer;
	RenderTarget renderTarget;
	Surface colorBuffer(0x100000, kFbWidth, kFbHeight);
	Surface zBuffer(0x240000, kFbWidth, kFbHeight);
	renderTarget.setColorBuffer(&colorBuffer);
	renderTarget.setZBuffer(&zBuffer);
	ParameterInterpolator interp(kFbWidth, kFbHeight);
#if TEXTURE_SHADER
	Surface texture((unsigned int) kImage, 128, 128);
	TextureShader shader(&interp, &renderTarget);
	shader.bindTexture(&texture);
#elif COLOR_SHADER
	ColorShader shader(&interp, &renderTarget);
#else
	CheckerboardShader shader(&interp, &renderTarget);
#endif

	shader.enableZBuffer(true);
//	shader.enableBlend(true);

	while (nextTileIndex < kMaxTileIndex)
	{
		// Grab the next available tile to begin working on.
		int myTileIndex = __sync_fetch_and_add(&nextTileIndex, 1);
		if (myTileIndex >= kMaxTileIndex)
			break;

		unsigned int tileXI, tileYI;
		udiv(myTileIndex, 10, tileYI, tileXI);
		int tileX = tileXI * 64;
		int tileY = tileYI * 64;

#if ENABLE_CLEAR
		renderTarget.getColorBuffer()->clearTile(tileX, tileY, 0);
#endif

		if (shader.isZBufferEnabled())
			renderTarget.getZBuffer()->clearTile(tileX, tileY, 0x40000000);

		// Cycle through all triangles and attempt to render into this 
		// 64x64 tile.
		for (int vidx = 0; vidx < gNumVertices; vidx += 3)
		{
			Vertex *vertex = &gVertices[vidx];

			// XXX could do some trivial rejections here for triangles that
			// obviously aren't in this tile.

			interp.setUpTriangle(
				vertex[0].coord[0], vertex[0].coord[1], vertex[0].coord[2],
				vertex[1].coord[0], vertex[1].coord[1], vertex[1].coord[2],
				vertex[2].coord[0], vertex[2].coord[1], vertex[2].coord[2]);

			for (int param = 0; param < gNumVertexParams; param++)
			{
				interp.setUpParam(param, vertex[0].params[param],
					vertex[1].params[param], vertex[2].params[param]);
			}

			rasterizer.rasterizeTriangle(&shader, tileX, tileY,
				(int)(vertex[0].coord[0] * kFbWidth), 
				(int)(vertex[0].coord[1] * kFbHeight), 
				(int)(vertex[1].coord[0] * kFbWidth), 
				(int)(vertex[1].coord[1] * kFbHeight), 
				(int)(vertex[2].coord[0] * kFbWidth), 
				(int)(vertex[2].coord[1] * kFbHeight));
		}

		renderTarget.getColorBuffer()->flushTile(tileX, tileY);
	}

#if COUNT_STATS	
	if (__builtin_vp_get_current_strand() == 0)
	{
		Debug::debug << renderTarget.getTotalPixels() << " total pixels\n";
		Debug::debug << renderTarget.getTotalBlocks() << " total blocks\n";
	}
#endif
	return 0;
}

Debug Debug::debug;
