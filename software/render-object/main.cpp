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
#define DRAW_TRIANGLE 0 

#define WIREFRAME 0
#define DRAW_TILE_OUTLINES 0

#include <math.h>
#include <schedule.h>
#include <stdlib.h>
#include "Matrix.h"
#include "PixelShader.h"
#include "Rasterizer.h"
#include "RenderTarget.h"
#include "TextureSampler.h"
#include "RenderUtils.h"
#include "VertexShader.h"
#include "TextureShader.h"
#include "PhongShader.h"
#if DRAW_TORUS 
	#include "torus.h"
#elif DRAW_CUBE
	#include "cube.h"
	#include "brick-texture.h"
#elif DRAW_TEAPOT
	#include "teapot.h"
#elif !DRAW_TRIANGLE
	#error Configure something to draw
#endif

using namespace render;

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
const int kTileRows = (kFbHeight + kTileSize - 1) / kTileSize;
const int kMaxVertices = 0x10000;
const int kMaxTriangles = 4096;

static float *gVertexParams;
static Triangle *gTriangles;
static Surface *gZBuffer;
static Surface *gColorBuffer;
static RenderTarget *gRenderTarget;
static Matrix gMVPMatrix;
static const float *gVertices;
static int gNumVertices;
static const int *gIndices;
static int gNumIndices;
static const void *gUniforms;
static int gNumVertexParams;
static float kTriangleVertices[] = {
	0.0, -0.9, 1.0, 0.0, 0.0, -1.0,
	0.9, 0.9, 1.0, 0.0, 0.0, -1.0,
	-0.9, 0.9, 1.0, 0.0, 0.0, -1.0
};

static int kTriangleIndices[] = { 0, 2, 1 };

static void drawLine(Surface *dest, int x1, int y1, int x2, int y2, unsigned int color)
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

static void shadeVertices(int index, int, int)
{
#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
	PhongVertexShader vertexShader;
#else
	TextureVertexShader vertexShader;
#endif

	int numVertices = gNumVertices - index * 16;
	if (numVertices > 16)
		numVertices = 16;
	
	vertexShader.processVertices(gVertexParams + vertexShader.getNumParams() * index * 16, 
		gVertices + vertexShader.getNumAttribs() * index * 16, gUniforms, numVertices);
}

static void setUpTriangle(int triangleIndex, int, int)
{
	int vertexIndex = triangleIndex * 3;

	Triangle &tri = gTriangles[triangleIndex];
	tri.offset0 = gIndices[vertexIndex] * gNumVertexParams;
	tri.offset1 = gIndices[vertexIndex + 1] * gNumVertexParams;
	tri.offset2 = gIndices[vertexIndex + 2] * gNumVertexParams;
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
	// This is an optimization: the rasterizer will not render 
	// triangles that are not facing the camera because of the way
	// the edge equations are computed. This avoids having to 
	// initialize the rasterizer unnecessarily.
	// However, this also removes triangles that are edge-on, 
	// which is useful because they won't be rasterized correctly.
	if ((tri.x1Rast - tri.x0Rast) * (tri.y2Rast - tri.y0Rast) - (tri.y1Rast - tri.y0Rast) 
		* (tri.x2Rast - tri.x0Rast) >= 0)
	{
		tri.visible = false;
		return;
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

static void fillTile(int x, int y, int)
{
	int tileX = x * kTileSize;
	int tileY = y * kTileSize;
	Rasterizer rasterizer(kFbWidth, kFbHeight);
	int numTriangles = gNumIndices / 3;

#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
	PhongPixelShader pixelShader(gRenderTarget);
#else
	TexturePixelShader pixelShader(gRenderTarget);
#endif

	pixelShader.enableZBuffer(true);
	gRenderTarget->getColorBuffer()->clearTile(tileX, tileY, 0);

	// Initialize Z-Buffer to infinity
	gRenderTarget->getZBuffer()->clearTile(tileX, tileY, 0x7f800000);

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
		drawLine(gColorBuffer, tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, 0xffffffff);
		drawLine(gColorBuffer, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast, 0xffffffff);
		drawLine(gColorBuffer, tri.x2Rast, tri.y2Rast, tri.x0Rast, tri.y0Rast, 0xffffffff);
#else
		// Set up parameters and rasterize triangle.
		pixelShader.setUpTriangle(tri.x0, tri.y0, tri.z0, tri.x1, tri.y1, tri.z1, tri.x2, 
			tri.y2, tri.z2);
		for (int paramI = 0; paramI < gNumVertexParams; paramI++)
		{
			pixelShader.setUpParam(paramI, 
				gVertexParams[tri.offset0 + paramI + 4],
				gVertexParams[tri.offset1 + paramI + 4], 
				gVertexParams[tri.offset2 + paramI + 4]);
		}

		rasterizer.fillTriangle(&pixelShader, gUniforms, tileX, tileY,
			tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast);	
#endif
	}
	
	gRenderTarget->getColorBuffer()->flushTile(tileX, tileY);
}

void *operator new(size_t size, void *p)
{
	return p;
}
	
int main()
{
	gRenderTarget = new RenderTarget();
	gColorBuffer = new (memalign(64, sizeof(Surface))) Surface(kFbWidth, kFbHeight, (void*) 0x200000);
	gRenderTarget->setColorBuffer(gColorBuffer);
	gZBuffer = new (memalign(64, sizeof(Surface))) Surface(kFbWidth, kFbHeight);
	gRenderTarget->setZBuffer(gZBuffer);
	gVertexParams = new float[kMaxVertices];
	gTriangles = new Triangle[kMaxTriangles];

#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
	PhongUniforms *uniforms = new PhongUniforms;
	gUniforms = uniforms;
	gNumVertexParams = 8;
#else
	TextureUniforms *uniforms = new TextureUniforms;
	uniforms->fTexture = new TextureSampler();
	uniforms->fTexture->bind(new (memalign(64, sizeof(Surface))) Surface(128, 128, (void*) kBrickTexture));
	uniforms->fTexture->setEnableBilinearFiltering(true);
	gUniforms = uniforms;
	gNumVertexParams = 6;
#endif

#if DRAW_TRIANGLE
	gVertices = kTriangleVertices;
	gNumVertices = 3;
	gIndices = kTriangleIndices;
	gNumIndices = 3;
#elif DRAW_TORUS
	gVertices = kTorusVertices;
	gNumVertices = kNumTorusVertices;
	gIndices = kTorusIndices;
	gNumIndices = kNumTorusIndices;
#elif DRAW_CUBE
	gVertices = kCubeVertices;	
	gNumVertices = kNumCubeVertices;
	gIndices = kCubeIndices;
	gNumIndices = kNumCubeIndices;
#elif DRAW_TEAPOT
	gVertices = kTeapotVertices;
	gNumVertices = kNumTeapotVertices;
	gIndices = kTeapotIndices;
	gNumIndices = kNumTeapotIndices;
#endif

	Matrix projectionMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);
	Matrix modelViewMatrix;
	Matrix rotationMatrix;

#if DRAW_TRIANGLE
	// modelViewMatrix is identity
#elif DRAW_TORUS
	modelViewMatrix = Matrix::getTranslationMatrix(0.0f, 0.0f, 1.5f);
	modelViewMatrix = modelViewMatrix * Matrix::getRotationMatrix(M_PI / 3.5, 0.707f, 0.707f, 0.0f);
#elif DRAW_CUBE
	modelViewMatrix = Matrix::getTranslationMatrix(0.0f, 0.0f, 2.0f);
	modelViewMatrix = modelViewMatrix * Matrix::getRotationMatrix(M_PI / 3.5, 0.707f, 0.707f, 0.0f);
#elif DRAW_TEAPOT
	modelViewMatrix = Matrix::getTranslationMatrix(0.0f, 0.1f, 0.25f);
	modelViewMatrix = modelViewMatrix * Matrix::getRotationMatrix(M_PI, -1.0f, 0.0f, 0.0f);
#endif
	
	rotationMatrix = Matrix::getRotationMatrix(M_PI / 8, 0.707f, 0.707f, 0.0f);

	for (int frame = 0; frame < 1; frame++)
	{
		uniforms->fMVPMatrix = projectionMatrix * modelViewMatrix;
#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
		uniforms->fNormalMatrix = modelViewMatrix.upper3x3();
#endif
		parallelExecuteAndSync(shadeVertices, (gNumVertices + 15) / 16, 1, 1);
		parallelExecuteAndSync(setUpTriangle, gNumIndices / 3, 1, 1);
		parallelExecuteAndSync(fillTile, kTilesPerRow, kTileRows, 1);
		modelViewMatrix = modelViewMatrix * rotationMatrix;
	}
	
	return 0;
}
