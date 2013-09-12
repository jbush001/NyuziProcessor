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
#include "VertexShader.h"
#include "utils.h"
#include "Barrier.h"

#define COLOR_SHADER 0
#define TEXTURE_SHADER 1

const int kMaxTileIndex = (640 / 64) * ((480 / 64) + 1);
int nextTileIndex = 0;
extern char *kImage;

class ColorPixelShader : public PixelShader
{
public:
	ColorPixelShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{}
	
	virtual void shadePixels(const vecf16 inParams[kMaxVertexParams], 
		vecf16 outColor[4], unsigned short mask);
};

void ColorPixelShader::shadePixels(const vecf16 inParams[kMaxVertexParams], 
	vecf16 outColor[4], unsigned short /* mask */)
{
	for (int i = 0; i < 3; i++)
		outColor[i] = inParams[i];

	outColor[3] = splatf(0.7f);
}

class CheckerboardPixelShader : public PixelShader
{
public:
	CheckerboardPixelShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{}
	
	virtual void shadePixels(const vecf16 inParams[kMaxVertexParams], 
		vecf16 outColor[4], unsigned short mask);
};

void CheckerboardPixelShader::shadePixels(const vecf16 inParams[kMaxVertexParams], 
	vecf16 outColor[4], unsigned short /* mask */)
{
	veci16 u = ((__builtin_vp_vftoi(inParams[0] * splatf(65535.0))) 
		>> splati(10)) & splati(1);
	veci16 v = ((__builtin_vp_vftoi(inParams[1] * splatf(65535.0))) 
		>> splati(10)) & splati(1);

	veci16 color = u ^ v;
	
	outColor[0] = outColor[1] = outColor[2] = __builtin_vp_vitof(color);
	outColor[3] = splatf(0.7f);
}

class TexturePixelShader : public PixelShader
{
public:
	TexturePixelShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{}
	
	void bindTexture(Surface *surface)
	{
		fSampler.bind(surface);
	}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outColor[4],
		unsigned short mask);
		
private:
	TextureSampler fSampler;
};

void TexturePixelShader::shadePixels(const vecf16 inParams[kMaxVertexParams], 
	vecf16 outColor[4], unsigned short mask)
{
	veci16 values = fSampler.readPixels(inParams[0], inParams[1]);

	outColor[2] = __builtin_vp_vitof((values >> splati(16)) & splati(255)) 
		/ splatf(255.0f); // R
	outColor[1] = __builtin_vp_vitof((values >> splati(8)) & splati(255)) 
		/ splatf(255.0f); // G
	outColor[0] = __builtin_vp_vitof(values & splati(255))
		/ splatf(255.0f);	// B
	outColor[3] = __builtin_vp_vitof((values >> splati(24)) & splati(255)) 
		/ splatf(255.0f); // A
}

class PassThruVertexShader : public VertexShader
{
public:
	PassThruVertexShader(int numAttribs, int numParams)
		:	VertexShader(numAttribs, numParams)
	{
	}
	
	void shadeVertices(vecf16 outParams[kMaxVertexAttribs],
		const vecf16 inAttribs[kMaxVertexAttribs], int mask)
	{
		// xyz
		outParams[0] = (inAttribs[0] * splatf(2.0f)) - splatf(1.0f); // x
		outParams[1] = (inAttribs[1] * splatf(2.0f)) - splatf(1.0f); // y
		outParams[2] = inAttribs[2]; // z
		outParams[3] = splatf(1.0f); // w

		// remaining params
		for (int i = 3; i < getNumParams(); i++)
			outParams[i + 1] = inAttribs[i];
	}
};	

const int kFbWidth = 640;
const int kFbHeight = 480;

// Hard-coded for now.  This normally would be generated during the geometry phase...
float gVertexAttribs[] = {
#if TEXTURE_SHADER
	0.3, 0.1, 0.4, 0.0, 0.0,
	0.9, 0.5, 0.5, 3.0, 0.0,
	0.1, 0.9, 0.1, 0.0, 3.0,
#elif COLOR_SHADER
	0.3, 0.1, 0.6, 1.0, 0.0, 0.0,
	0.9, 0.5, 0.4, 0.0, 1.0, 0.0,
	0.1, 0.9, 0.1, 0.0, 0.0, 1.0,

	0.3, 0.9, 0.3, 1.0, 1.0, 0.0,
	0.5, 0.1, 0.3, 0.0, 1.0, 1.0,
	0.8, 0.8, 0.3, 1.0, 0.0, 1.0,
#else
	// Checkerboard
	0.3, 0.1, 0.6, 0.0, 0.0,
	0.9, 0.5, 0.4, 0.0, 1.0,
	0.1, 0.9, 0.1, 1.0, 1.0,

	0.3, 0.9, 0.3, 1.0, 1.0,
	0.5, 0.1, 0.3, 0.0, 1.0,
	0.8, 0.8, 0.3, 1.0, 0.0,
#endif
};

float gVertexParams[512];

#if COLOR_SHADER
int gNumVertexParams = 7;	// X Y Z R G B
#else
int gNumVertexParams = 6;	// X Y Z U V
#endif

#if TEXTURE_SHADER
int gNumVertices = 3;
#else
int gNumVertices = 6;
#endif

Barrier<4> gGeometryBarrier;
Barrier<4> gPixelBarrier;

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
	TexturePixelShader pixelShader(&interp, &renderTarget);
	pixelShader.bindTexture(&texture);
#elif COLOR_SHADER
	ColorPixelShader pixelShader(&interp, &renderTarget);
#else
	CheckerboardPixelShader pixelShader(&interp, &renderTarget);
#endif
	PassThruVertexShader vertexShader(gNumVertexParams - 1, gNumVertexParams);

	pixelShader.enableZBuffer(true);
//	pixelShader.enableBlend(true);

	//
	// Geometry phase
	//
	if (__builtin_vp_get_current_strand() == 0)
		vertexShader.processVertexBuffer(gVertexParams, gVertexAttribs, gNumVertices);

	gGeometryBarrier.wait();
	
	//
	// Pixel phase
	//
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

		if (pixelShader.isZBufferEnabled())
			renderTarget.getZBuffer()->clearTile(tileX, tileY, 0x40000000);

		// Cycle through all triangles and attempt to render into this 
		// 64x64 tile.
		float *params = gVertexParams;
		for (int vidx = 0; vidx < gNumVertices; vidx += 3)
		{
			// XXX could do some trivial rejections here for triangles that
			// obviously aren't in this tile.
			float x0 = params[kParamX];
			float y0 = params[kParamY];
			float z0 = params[kParamZ];
			float x1 = params[gNumVertexParams + kParamX];
			float y1 = params[gNumVertexParams + kParamY];
			float z1 = params[gNumVertexParams + kParamZ];
			float x2 = params[gNumVertexParams * 2 + kParamX];
			float y2 = params[gNumVertexParams * 2 + kParamY];
			float z2 = params[gNumVertexParams * 2 + kParamZ];

			interp.setUpTriangle(x0, y0, z0, x1, y1, z1, x2, y2, z2);
			for (int paramI = 0; paramI < gNumVertexParams; paramI++)
			{
				interp.setUpParam(paramI, 
					params[paramI + 4],
					params[gNumVertexParams + paramI + 4], 
					params[gNumVertexParams * 2 + paramI + 4]);
			}

			rasterizer.rasterizeTriangle(&pixelShader, tileX, tileY,
				(int)(x0 * kFbWidth / 2 + kFbWidth / 2), 
				(int)(y0 * kFbHeight / 2 + kFbHeight / 2), 
				(int)(x1 * kFbWidth / 2 + kFbWidth / 2), 
				(int)(y1 * kFbHeight / 2 + kFbHeight / 2), 
				(int)(x2 * kFbWidth / 2 + kFbWidth / 2), 
				(int)(y2 * kFbHeight / 2 + kFbHeight / 2));

			params += gNumVertexParams * 3;
		}

		renderTarget.getColorBuffer()->flushTile(tileX, tileY);
	}

	gPixelBarrier.wait();

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
