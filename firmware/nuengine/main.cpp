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

#define DRAW_TORUS 0
#define DRAW_CUBE 0
#define DRAW_TEAPOT 1

#include "assert.h"
#include "Barrier.h"
#include "Debug.h"
#include "Matrix.h"
#include "ParameterInterpolator.h"
#include "PixelShader.h"
#include "Rasterizer.h"
#include "RenderTarget.h"
#include "TextureSampler.h"
#include "utils.h"
#include "VertexShader.h"
#if DRAW_TORUS 
	#include "torus.h"
#elif DRAW_CUBE
	#include "cube.h"
	#include "brick-texture.h"
#elif DRAW_TEAPOT
	#include "teapot.h"
#else
	#error Configure something to draw
#endif

#define ENABLE_BACKFACE_CULL 1
#define ENABLE_BOUNDING_BOX_CHECK 1

const int kFbWidth = 640;
const int kFbHeight = 512;	// Round up to 64 pixel boundary

class TextureVertexShader : public VertexShader
{
public:
	TextureVertexShader()
		:	VertexShader(5, 6)
	{
		const float kAspectRatio = float(kFbWidth) / float(kFbHeight);
		const float kProjCoeff[4][4] = {
			{ 1.0f / kAspectRatio, 0.0f, 0.0f, 0.0f },
			{ 0.0f, kAspectRatio, 0.0f, 0.0f },
			{ 0.0f, 0.0f, 1.0f, 0.0f },
			{ 0.0f, 0.0f, 1.0f, 0.0f }
		};

		fProjectionMatrix = Matrix(kProjCoeff);
		fMVPMatrix = fProjectionMatrix;
	}
	
	void applyTransform(const Matrix &mat)
	{
		fModelViewMatrix = fModelViewMatrix * mat;
		fMVPMatrix = fProjectionMatrix * fModelViewMatrix;
	}

	void shadeVertices(vecf16 outParams[kMaxVertexAttribs],
		const vecf16 inAttribs[kMaxVertexAttribs], int mask)
	{
		// Multiply by mvp matrix
		vecf16 coord[4];
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i];
			
		coord[3] = splatf(1.0f);
		fMVPMatrix.mulVec(outParams, coord); 

		// Copy remaining parameters
		outParams[4] = inAttribs[3];
		outParams[5] = inAttribs[4];
	}
	
private:
	Matrix fMVPMatrix;
	Matrix fProjectionMatrix;
	Matrix fModelViewMatrix;
};

class TexturePixelShader : public PixelShader
{
public:
	TexturePixelShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{}
	
	void bindTexture(Surface *surface)
	{
		fSampler.bind(surface);
		fSampler.setEnableBilinearFiltering(true);
	}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outColor[4],
		unsigned short mask)
	{
		fSampler.readPixels(inParams[0], inParams[1], mask, outColor);
	}
		
private:
	TextureSampler fSampler;
};

class LightingVertexShader : public VertexShader
{
public:
	LightingVertexShader()
		:	VertexShader(6, 8)
	{
		const float kAspectRatio = float(kFbWidth) / float(kFbHeight);
		const float kProjCoeff[4][4] = {
			{ 1.0f / kAspectRatio, 0.0f, 0.0f, 0.0f },
			{ 0.0f, kAspectRatio, 0.0f, 0.0f },
			{ 0.0f, 0.0f, 1.0f, 0.0f },
			{ 0.0f, 0.0f, 1.0f, 0.0f },
		};

		fProjectionMatrix = Matrix(kProjCoeff);
		applyTransform(Matrix());
	}
	
	void applyTransform(const Matrix &mat)
	{
		fModelViewMatrix = fModelViewMatrix * mat;
		fMVPMatrix = fProjectionMatrix * fModelViewMatrix;
		fNormalMatrix = fModelViewMatrix.upper3x3();
	}

	void shadeVertices(vecf16 outParams[kMaxVertexAttribs],
		const vecf16 inAttribs[kMaxVertexAttribs], int mask)
	{
		// Multiply by mvp matrix
		vecf16 coord[4];
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i];
			
		coord[3] = splatf(1.0f);
		fMVPMatrix.mulVec(outParams, coord); 

		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i + 3];
			
		coord[3] = splatf(1.0f);
		
		fNormalMatrix.mulVec(outParams + 4, coord); 
	}

private:
	Matrix fMVPMatrix;
	Matrix fProjectionMatrix;
	Matrix fModelViewMatrix;
	Matrix fNormalMatrix;
};

class LightingPixelShader : public PixelShader
{
public:
	LightingPixelShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{
		fLightVector[0] = 0.7071067811f;
		fLightVector[1] = 0.7071067811f; 
		fLightVector[2] = 0.0f;

		fDirectional = 0.6f;		
		fAmbient = 0.2f;
	}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outColor[4],
		unsigned short mask)
	{
		// Dot product
		vecf16 dot = -inParams[0] * splatf(fLightVector[0])
			+ -inParams[1] * splatf(fLightVector[1])
			+ -inParams[2] * splatf(fLightVector[2]);
		dot *= splatf(fDirectional);
		outColor[1] = outColor[2] = splatf(0.0f);
		outColor[0] = clampvf(dot) + splatf(fAmbient);
		outColor[3] = splatf(1.0f);
	}

private:
	float fLightVector[3];
	float fAmbient;
	float fDirectional;
};

const int kTilesPerRow = kFbWidth / kTileSize;
const int kMaxTileIndex = kTilesPerRow * ((kFbHeight / 64) + 1);
Barrier<4> gGeometryBarrier;
Barrier<4> gPixelBarrier;
volatile int gNextTileIndex = 0;
float *gVertexParams;
Surface gZBuffer(0, kFbWidth, kFbHeight);
Surface gColorBuffer(0x100000, kFbWidth, kFbHeight);
#if DRAW_CUBE
	Surface texture((unsigned int) kBrickTexture, 128, 128);
#endif
Debug Debug::debug;

Matrix translate(float x, float y, float z)
{
	float kValues[4][4] = {
		{ 1.0f, 0.0f, 0.0f, x }, 
		{ 0.0f, 1.0f, 0.0f, y }, 
		{ 0.0f, 0.0f, 1.0f, z }, 
		{ 0.0f, 0.0f, 0.0f, 1.0f }, 
	};

	return Matrix(kValues);
}

Matrix rotateAboutAxis(float angle, float x, float y, float z)
{
	float s = sin(angle);
	float c = cos(angle);
	float t = 1.0f - c;

	float kMat1[4][4] = {
		{ (t * x * x + c), (t * x * y - s * z), (t * x * y + s * y), 0.0f },
		{ (t * x * y + s * z), (t * y * y + c), (t * x * z - s * x), 0.0f },
		{ (t * x * y - s * y), (t * y * z + s * x), (t * z * z + c), 0.0f },
		{ 0.0f, 0.0f, 0.0f, 1.0f }
	};
	
	return Matrix(kMat1);
}

//
// All threads start execution here
//
int main()
{
	Rasterizer rasterizer;
	RenderTarget renderTarget;
	renderTarget.setColorBuffer(&gColorBuffer);
	renderTarget.setZBuffer(&gZBuffer);
	ParameterInterpolator interp(kFbWidth, kFbHeight);
#if DRAW_TORUS
	LightingVertexShader vertexShader;
	LightingPixelShader pixelShader(&interp, &renderTarget);
	const float *vertices = kTorusVertices;
	int numVertices = kNumTorusVertices;
	const int *indices = kTorusIndices;
	int numIndices = kNumTorusIndices;
#elif DRAW_CUBE
	TextureVertexShader vertexShader;
	TexturePixelShader pixelShader(&interp, &renderTarget);
	pixelShader.bindTexture(&texture);
	const float *vertices = kCubeVertices;	
	int numVertices = kNumCubeVertices;
	const int *indices = kCubeIndices;
	int numIndices = kNumCubeIndices;
#elif DRAW_TEAPOT
	LightingVertexShader vertexShader;
	LightingPixelShader pixelShader(&interp, &renderTarget);
	const float *vertices = kTeapotVertices;
	int numVertices = kNumTeapotVertices;
	const int *indices = kTeapotIndices;
	int numIndices = kNumTeapotIndices;
#endif

#if DRAW_TORUS
	vertexShader.applyTransform(translate(0.0f, 0.0f, 1.5f));
	vertexShader.applyTransform(rotateAboutAxis(M_PI / 3.5, 0.707f, 0.707f, 0.0f));
#elif DRAW_CUBE
	vertexShader.applyTransform(translate(0.0f, 0.0f, 2.0f));
	vertexShader.applyTransform(rotateAboutAxis(M_PI / 3.5, 0.707f, 0.707f, 0.0f));
#elif DRAW_TEAPOT
	vertexShader.applyTransform(translate(0.0f, 0.1f, 0.25f));
	vertexShader.applyTransform(rotateAboutAxis(M_PI, -1.0f, 0.0f, 0.0f));
#endif

	Matrix rotateStepMatrix(rotateAboutAxis(M_PI / 8, 0.707f, 0.707f, 0.0f));
	
	pixelShader.enableZBuffer(true);
//	pixelShader.enableBlend(true);


	int numVertexParams = vertexShader.getNumParams();

	for (int frame = 0; frame < 1; frame++)
	{
		//
		// Geometry phase
		//
		if (__builtin_vp_get_current_strand() == 0)
		{
			if (gVertexParams == 0)
				gVertexParams = (float*) allocMem(16384 * sizeof(float));
		
			vertexShader.processVertexBuffer(gVertexParams, vertices, numVertices);
			vertexShader.applyTransform(rotateStepMatrix);
			gNextTileIndex = 0;
		}
		
		gGeometryBarrier.wait();

		//
		// Pixel phase
		//
		while (gNextTileIndex < kMaxTileIndex)
		{
			// Grab the next available tile to begin working on.
			int myTileIndex = __sync_fetch_and_add(&gNextTileIndex, 1);
			if (myTileIndex >= kMaxTileIndex)
				break;

			int tileX = (myTileIndex % kTilesPerRow) * kTileSize;
			int tileY = (myTileIndex / kTilesPerRow) * kTileSize;

			renderTarget.getColorBuffer()->clearTile(tileX, tileY, 0);
			if (pixelShader.isZBufferEnabled())
			{
				// XXX Ideally, we'd initialize to infinity, but comparisons
				// with infinity are broken in hardware.  For now, initialize
				// to a very large number
				renderTarget.getZBuffer()->clearTile(tileX, tileY, 0x7e000000);
			}
			
			// Cycle through all triangles and attempt to render into this 
			// 64x64 tile.
			for (int vidx = 0; vidx < numIndices; vidx += 3)
			{
				int offset0 = indices[vidx] * numVertexParams;
				int offset1 = indices[vidx + 1] * numVertexParams;
				int offset2 = indices[vidx + 2] * numVertexParams;
			
				float x0 = gVertexParams[offset0 + kParamX];
				float y0 = gVertexParams[offset0 + kParamY];
				float z0 = gVertexParams[offset0 + kParamZ];
				float x1 = gVertexParams[offset1 + kParamX];
				float y1 = gVertexParams[offset1 + kParamY];
				float z1 = gVertexParams[offset1 + kParamZ];
				float x2 = gVertexParams[offset2 + kParamX];
				float y2 = gVertexParams[offset2 + kParamY];
				float z2 = gVertexParams[offset2 + kParamZ];

				// Convert screen space coordinates to raster coordinates
				int x0Rast = x0 * kFbWidth / 2 + kFbWidth / 2;
				int y0Rast = y0 * kFbHeight / 2 + kFbHeight / 2;
				int x1Rast = x1 * kFbWidth / 2 + kFbWidth / 2;
				int y1Rast = y1 * kFbHeight / 2 + kFbHeight / 2;
				int x2Rast = x2 * kFbWidth / 2 + kFbWidth / 2;
				int y2Rast = y2 * kFbHeight / 2 + kFbHeight / 2;

#if ENABLE_BACKFACE_CULL
				// Backface cull triangles that are facing away from camera.
				// We also remove triangles that are edge on here, since they
				// won't be rasterized correctly.
				if ((x1Rast - x0Rast) * (y2Rast - y0Rast) - (y1Rast - y0Rast) 
					* (x2Rast - x0Rast) <= 0)
					continue;
#endif

#if ENABLE_BOUNDING_BOX_CHECK
				// Bounding box check.  If triangles are not within this tile,
				// skip them.
				int xMax = tileX + kTileSize;
				int yMax = tileY + kTileSize;
				if ((x0Rast < tileX && x1Rast < tileX && x2Rast < tileX)
					|| (y0Rast < tileY && y1Rast < tileY && y2Rast < tileY)
					|| (x0Rast > xMax && x1Rast > xMax && x2Rast > xMax)
					|| (y0Rast > yMax && y1Rast > yMax && y2Rast > yMax))
					continue;
#endif

				// Set up parameters and rasterize triangle.
				interp.setUpTriangle(x0, y0, z0, x1, y1, z1, x2, y2, z2);
				for (int paramI = 0; paramI < numVertexParams; paramI++)
				{
					interp.setUpParam(paramI, 
						gVertexParams[offset0 + paramI + 4],
						gVertexParams[offset1 + paramI + 4], 
						gVertexParams[offset2 + paramI + 4]);
				}

				rasterizer.rasterizeTriangle(&pixelShader, tileX, tileY,
					x0Rast, y0Rast, x1Rast, y1Rast, x2Rast, y2Rast);
			}

			renderTarget.getColorBuffer()->flushTile(tileX, tileY);
		}

		gPixelBarrier.wait();
	}
	
	return 0;
}
