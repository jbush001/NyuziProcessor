// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


#define DRAW_TORUS 0
#define DRAW_CUBE 0
#define DRAW_TEAPOT 1
#define GOURAND_SHADER 0
#define WIREFRAME 0
#define DRAW_TILE_OUTLINES 0

#include <math.h>
#include "Barrier.h"
#include "Matrix.h"
#include "PixelShader.h"
#include "Rasterizer.h"
#include "RenderTarget.h"
#include "TextureSampler.h"
#include "RenderUtils.h"
#include "VertexShader.h"
#include "TextureShader.h"
#include "GourandShader.h"
#include "PhongShader.h"
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

using namespace render;
using namespace runtime;

struct Triangle 
{
	float x0, y0, z0, x1, y1, z1, x2, y2, z2;
	int x0Rast, y0Rast, x1Rast, y1Rast, x2Rast, y2Rast;
	bool visible;
	int bbLeft, bbTop, bbRight, bbBottom;
	int offset0, offset1, offset2;
};

const int kFbWidth = 640;
const int kFbHeight = 480;
const int kTilesPerRow = (kFbWidth + kTileSize - 1) / kTileSize;
const int kMaxTileIndex = kTilesPerRow * ((kFbHeight + kTileSize - 1) / kTileSize);
const int kMaxVertices = 0x10000;
const int kMaxTriangles = 4096;

Barrier gGeometryBarrier;
Barrier gSetupBarrier;
Barrier gPixelBarrier;
Barrier gInitBarrier;
volatile int gNextTileIndex = 0;
float *gVertexParams;
Triangle *gTriangles;
render::Surface gZBuffer(0, kFbWidth, kFbHeight);
render::Surface gColorBuffer(0x200000, kFbWidth, kFbHeight);
#if DRAW_CUBE
	render::Surface texture((unsigned int) kBrickTexture, 128, 128);
#endif

inline int currentThread()
{
	return __builtin_nyuzi_read_control_reg(0);
}

void drawLine(Surface *dest, int x1, int y1, int x2, int y2, unsigned int color)
{
	// Swap if necessary so we always draw top to bottom
	if (y1 > y2) 
	{
		int temp = y1;
		y1 = y2;
		y2 = temp;

		temp = x1;
		x1 = x2;
		x2 = temp;
	}

	int deltaY = (y2 - y1) + 1;
	int deltaX = x2 > x1 ? (x2 - x1) + 1 : (x1 - x2) + 1;
	int xDir = x2 > x1 ? 1 : -1;
	int error = 0;
	unsigned int *ptr = ((unsigned int*) dest->lockBits()) + x1 + y1 * dest->getWidth();
	int stride = dest->getWidth();

	if (deltaX == 0) 
	{
		// Vertical line
		for (int y = deltaY; y > 0; y--) 
		{
			*ptr = color;
			ptr += stride;
		}
	} 
	else if (deltaY == 0) 
	{
		// Horizontal line
		for (int x = deltaX; x > 0; x--) 
		{
			*ptr = color;
			ptr += xDir;
		}
	} 
	else if (deltaX > deltaY) 
	{
		// Diagonal with horizontal major axis
		int x = x1;
		for (;;) 
		{
			*ptr = color;
			error += deltaY;
			if (error > deltaX) 
			{
				ptr += stride;
				error -= deltaX;
			}

			ptr += xDir;
			if (x == x2)
				break;

			x += xDir;
		}
	} 
	else 
	{
		// Diagonal with vertical major axis
		for (int y = y1; y <= y2; y++) 
		{
			*ptr = color;
			error += deltaX;
			if (error > deltaY) 
			{
				ptr += xDir;
				error -= deltaY;
			}

			ptr += stride;
		}
	}
}

//
// All hardware threads start execution here
//
int main()
{
	__builtin_nyuzi_write_control_reg(30, 0xf);	// Start other threads if this is thread 0
	
	render::Rasterizer rasterizer(kFbWidth, kFbHeight);
	render::RenderTarget renderTarget;
	renderTarget.setColorBuffer(&gColorBuffer);
	renderTarget.setZBuffer(&gZBuffer);
#if DRAW_TORUS
#if GOURAND_SHADER
	GourandVertexShader vertexShader;
	GourandPixelShader pixelShader(&renderTarget);
#else
	PhongVertexShader vertexShader;
	PhongPixelShader pixelShader(&renderTarget);
#endif

	const float *vertices = kTorusVertices;
	int numVertices = kNumTorusVertices;
	const int *indices = kTorusIndices;
	int numIndices = kNumTorusIndices;
#elif DRAW_CUBE
	TextureVertexShader vertexShader;
	TexturePixelShader pixelShader(&renderTarget);
	pixelShader.bindTexture(&texture);
	const float *vertices = kCubeVertices;	
	int numVertices = kNumCubeVertices;
	const int *indices = kCubeIndices;
	int numIndices = kNumCubeIndices;
#elif DRAW_TEAPOT
#if GOURAND_SHADER
	GourandVertexShader vertexShader;
	GourandPixelShader pixelShader(&renderTarget);
#else
	PhongVertexShader vertexShader;
	PhongPixelShader pixelShader(&renderTarget);
#endif

	const float *vertices = kTeapotVertices;
	int numVertices = kNumTeapotVertices;
	const int *indices = kTeapotIndices;
	int numIndices = kNumTeapotIndices;
#endif

	vertexShader.setProjectionMatrix(Matrix::getProjectionMatrix(kFbWidth, kFbHeight));

#if DRAW_TORUS
	vertexShader.applyTransform(Matrix::getTranslationMatrix(0.0f, 0.0f, 1.5f));
	vertexShader.applyTransform(Matrix::getRotationMatrix(M_PI / 3.5, 0.707f, 0.707f, 0.0f));
#elif DRAW_CUBE
	vertexShader.applyTransform(Matrix::getTranslationMatrix(0.0f, 0.0f, 2.0f));
	vertexShader.applyTransform(Matrix::getRotationMatrix(M_PI / 3.5, 0.707f, 0.707f, 0.0f));
#elif DRAW_TEAPOT
	vertexShader.applyTransform(Matrix::getTranslationMatrix(0.0f, 0.1f, 0.25f));
	vertexShader.applyTransform(Matrix::getRotationMatrix(M_PI, -1.0f, 0.0f, 0.0f));
#endif

	Matrix rotateStepMatrix(Matrix::getRotationMatrix(M_PI / 8, 0.707f, 0.707f, 0.0f));
	
	pixelShader.enableZBuffer(true);
	if (currentThread() == 0)
	{
		gVertexParams = new float[kMaxVertices];
		gTriangles = new Triangle[kMaxTriangles];
	}

	gInitBarrier.wait();

	int numVertexParams = vertexShader.getNumParams();

	for (int frame = 0; frame < 1; frame++)
	{
		//
		// Geometry phase.  
		//
		
		// Vertex Shading.
		// Statically assign groups of 16 vertices to threads. Although these may be 
		// handled in arbitrary order, they are put into gVertexParams in proper order (this is a sort
		// middle architecture, and gVertexParams is in the middle).
		int vertexIndex = currentThread() * 16;
		while (vertexIndex < numVertices)
		{
			vertexShader.processVertices(gVertexParams + vertexShader.getNumParams() * vertexIndex, 
				vertices + vertexShader.getNumAttribs() * vertexIndex, numVertices - vertexIndex);
			vertexIndex += 16 * kNumCores * kHardwareThreadsPerCore;
		}

		gGeometryBarrier.wait();

		// Triangle setup. The triangles are assigned to threads in an interleaved 
		// pattern.
		int numTriangles = numIndices / 3;
		for (int triangleIndex = currentThread(); triangleIndex < numTriangles; 
			triangleIndex += kNumCores * kHardwareThreadsPerCore)
		{
			int vertexIndex = triangleIndex * 3;

			Triangle &tri = gTriangles[triangleIndex];
			tri.offset0 = indices[vertexIndex] * numVertexParams;
			tri.offset1 = indices[vertexIndex + 1] * numVertexParams;
			tri.offset2 = indices[vertexIndex + 2] * numVertexParams;
			tri.x0 = gVertexParams[tri.offset0 + kParamX];
			tri.y0 = gVertexParams[tri.offset0 + kParamY];
			tri.z0 = gVertexParams[tri.offset0 + kParamZ];
			tri.x1 = gVertexParams[tri.offset1 + kParamX];
			tri.y1 = gVertexParams[tri.offset1 + kParamY];
			tri.z1 = gVertexParams[tri.offset1 + kParamZ];
			tri.x2 = gVertexParams[tri.offset2 + kParamX];
			tri.y2 = gVertexParams[tri.offset2 + kParamY];
			tri.z2 = gVertexParams[tri.offset2 + kParamZ];

			// Convert screen space coordinates to raster coordinates
			tri.x0Rast = tri.x0 * kFbWidth / 2 + kFbWidth / 2;
			tri.y0Rast = tri.y0 * kFbHeight / 2 + kFbHeight / 2;
			tri.x1Rast = tri.x1 * kFbWidth / 2 + kFbWidth / 2;
			tri.y1Rast = tri.y1 * kFbHeight / 2 + kFbHeight / 2;
			tri.x2Rast = tri.x2 * kFbWidth / 2 + kFbWidth / 2;
			tri.y2Rast = tri.y2 * kFbHeight / 2 + kFbHeight / 2;

			// Backface cull triangles that are facing away from camera.
			// We also remove triangles that are edge on here, since they
			// won't be rasterized correctly.
			if ((tri.x1Rast - tri.x0Rast) * (tri.y2Rast - tri.y0Rast) - (tri.y1Rast - tri.y0Rast) 
				* (tri.x2Rast - tri.x0Rast) >= 0)
			{
				tri.visible = false;
				continue;
			}
						
			tri.visible = true;
			
			// Compute bounding box
			tri.bbLeft = tri.x0Rast < tri.x1Rast ? tri.x0Rast : tri.x1Rast;
			tri.bbLeft = tri.x2Rast < tri.bbLeft ? tri.x2Rast : tri.bbLeft;
			tri.bbTop = tri.y0Rast < tri.y1Rast ? tri.y0Rast : tri.y1Rast;
			tri.bbTop = tri.y2Rast < tri.bbTop ? tri.y2Rast : tri.bbTop;
			tri.bbRight = tri.x0Rast > tri.x1Rast ? tri.x0Rast : tri.x1Rast;
			tri.bbRight = tri.x2Rast > tri.bbRight ? tri.x2Rast : tri.bbRight;
			tri.bbBottom = tri.y0Rast > tri.y1Rast ? tri.y0Rast : tri.y1Rast;
			tri.bbBottom = tri.y2Rast > tri.bbBottom ? tri.y2Rast : tri.bbBottom;
		}

		if (currentThread() == 0)
			gNextTileIndex = 0;

		vertexShader.applyTransform(rotateStepMatrix);
		gSetupBarrier.wait();

		//
		// Pixel phase
		//
		while (gNextTileIndex < kMaxTileIndex)
		{
			// Grab the next available tile to fill.
			int myTileIndex = __sync_fetch_and_add(&gNextTileIndex, 1);
			if (myTileIndex >= kMaxTileIndex)
				break;

			int tileX = (myTileIndex % kTilesPerRow) * kTileSize;
			int tileY = (myTileIndex / kTilesPerRow) * kTileSize;

			renderTarget.getColorBuffer()->clearTile(tileX, tileY, 0);
			if (pixelShader.isZBufferEnabled())
			{
				// Initialize Z-Buffer to infinity
				renderTarget.getZBuffer()->clearTile(tileX, tileY, 0x7f800000);
			}

			// Cycle through all triangles and attempt to render into this 
			// NxN tile.
			for (int triangleIndex = 0; triangleIndex < numTriangles; triangleIndex++)
			{
				Triangle &tri = gTriangles[triangleIndex];
				if (!tri.visible)
					continue;

				// Bounding box check.  If triangles are not within this tile,
				// skip them.
				int xMax = tileX + kTileSize;
				int yMax = tileY + kTileSize;
				if (tri.bbRight < tileX || tri.bbBottom < tileY || tri.bbLeft > xMax
					|| tri.bbTop > yMax)
					continue;
				
#if WIREFRAME
				drawLine(&gColorBuffer, tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, 0xffffffff);
				drawLine(&gColorBuffer, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast, 0xffffffff);
				drawLine(&gColorBuffer, tri.x2Rast, tri.y2Rast, tri.x0Rast, tri.y0Rast, 0xffffffff);
#else
				// Set up parameters and rasterize triangle.
				pixelShader.setUpTriangle(tri.x0, tri.y0, tri.z0, tri.x1, tri.y1, tri.z1, tri.x2, 
					tri.y2, tri.z2);
				for (int paramI = 0; paramI < numVertexParams; paramI++)
				{
					pixelShader.setUpParam(paramI, 
						gVertexParams[tri.offset0 + paramI + 4],
						gVertexParams[tri.offset1 + paramI + 4], 
						gVertexParams[tri.offset2 + paramI + 4]);
				}

				rasterizer.fillTriangle(&pixelShader, tileX, tileY,
					tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast);
#endif
			}

#if DRAW_TILE_OUTLINES
			drawLine(&gColorBuffer, tileX, tileY, tileX + kTileSize, tileY, 0x00008000);
			drawLine(&gColorBuffer, tileX, tileY, tileX, tileY + kTileSize, 0x00008000);
#endif
			renderTarget.getColorBuffer()->flushTile(tileX, tileY);
		}
		
		gPixelBarrier.wait();
	}
	
	return 0;
}
