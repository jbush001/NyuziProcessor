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

struct RenderContext
{
	float *vertexParams;
	Triangle *triangles;
	Surface *zBuffer;
	Surface *colorBuffer;
	RenderTarget *renderTarget;
	Matrix mvpMatrix;
	const float *vertices;
	int numVertices;
	const int *indices;
	int numIndices;
	const void *uniforms;
	int numVertexParams;	
};

const int kFbWidth = 640;
const int kFbHeight = 480;
const int kTilesPerRow = (kFbWidth + kTileSize - 1) / kTileSize;
const int kTileRows = (kFbHeight + kTileSize - 1) / kTileSize;
const int kMaxVertices = 0x10000;
const int kMaxTriangles = 4096;

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

static void shadeVertices(void *_castToContext, int index, int, int)
{
	RenderContext *context = (RenderContext*) _castToContext;
#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
	PhongVertexShader vertexShader;
#else
	TextureVertexShader vertexShader;
#endif

	int numVertices = context->numVertices - index * 16;
	if (numVertices > 16)
		numVertices = 16;
	
	vertexShader.processVertices(context->vertexParams + vertexShader.getNumParams() 
		* index * 16, context->vertices + vertexShader.getNumAttribs() * index * 16, 
		context->uniforms, numVertices);
}

static void setUpTriangle(void *_castToContext, int triangleIndex, int, int)
{
	RenderContext *context = (RenderContext*) _castToContext;
	int vertexIndex = triangleIndex * 3;

	Triangle &tri = context->triangles[triangleIndex];
	tri.offset0 = context->indices[vertexIndex] * context->numVertexParams;
	tri.offset1 = context->indices[vertexIndex + 1] * context->numVertexParams;
	tri.offset2 = context->indices[vertexIndex + 2] * context->numVertexParams;
	tri.x0 = context->vertexParams[tri.offset0 + kParamX];
	tri.y0 = context->vertexParams[tri.offset0 + kParamY];
	tri.z0 = context->vertexParams[tri.offset0 + kParamZ];
	tri.x1 = context->vertexParams[tri.offset1 + kParamX];
	tri.y1 = context->vertexParams[tri.offset1 + kParamY];
	tri.z1 = context->vertexParams[tri.offset1 + kParamZ];
	tri.x2 = context->vertexParams[tri.offset2 + kParamX];
	tri.y2 = context->vertexParams[tri.offset2 + kParamY];
	tri.z2 = context->vertexParams[tri.offset2 + kParamZ];
	
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

static void fillTile(void *_castToContext, int x, int y, int)
{
	RenderContext *context = (RenderContext*) _castToContext;
	
	int tileX = x * kTileSize;
	int tileY = y * kTileSize;
	Rasterizer rasterizer(kFbWidth, kFbHeight);
	int numTriangles = context->numIndices / 3;

#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
	PhongPixelShader pixelShader(context->renderTarget);
#else
	TexturePixelShader pixelShader(context->renderTarget);
#endif

	pixelShader.enableZBuffer(true);
	context->renderTarget->getColorBuffer()->clearTile(tileX, tileY, 0);

	// Initialize Z-Buffer to infinity
	context->renderTarget->getZBuffer()->clearTile(tileX, tileY, 0x7f800000);

	// Cycle through all triangles and attempt to render into this 
	// NxN tile.
	for (int triangleIndex = 0; triangleIndex < numTriangles; triangleIndex++)
	{
		Triangle &tri = context->triangles[triangleIndex];
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
		drawLine(context->colorBuffer, tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, 0xffffffff);
		drawLine(context->colorBuffer, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast, 0xffffffff);
		drawLine(context->colorBuffer, tri.x2Rast, tri.y2Rast, tri.x0Rast, tri.y0Rast, 0xffffffff);
#else
		// Set up parameters and rasterize triangle.
		pixelShader.setUpTriangle(tri.x0, tri.y0, tri.z0, tri.x1, tri.y1, tri.z1, tri.x2, 
			tri.y2, tri.z2);
		for (int paramI = 0; paramI < context->numVertexParams; paramI++)
		{
			pixelShader.setUpParam(paramI, 
				context->vertexParams[tri.offset0 + paramI + 4],
				context->vertexParams[tri.offset1 + paramI + 4], 
				context->vertexParams[tri.offset2 + paramI + 4]);
		}

		rasterizer.fillTriangle(&pixelShader, context->uniforms, tileX, tileY,
			tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast);	
#endif
	}
	
	context->renderTarget->getColorBuffer()->flushTile(tileX, tileY);
}

void *operator new(size_t size, void *p)
{
	return p;
}
	
int main()
{
	RenderContext *context = new RenderContext;
	
	context->renderTarget = new RenderTarget();
	context->colorBuffer = new (memalign(64, sizeof(Surface))) Surface(kFbWidth, kFbHeight, (void*) 0x200000);
	context->renderTarget->setColorBuffer(context->colorBuffer);
	context->zBuffer = new (memalign(64, sizeof(Surface))) Surface(kFbWidth, kFbHeight);
	context->renderTarget->setZBuffer(context->zBuffer);
	context->vertexParams = new float[kMaxVertices];
	context->triangles = new Triangle[kMaxTriangles];

#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
	PhongUniforms *uniforms = new PhongUniforms;
	context->uniforms = uniforms;
	context->numVertexParams = 8;
#else
	TextureUniforms *uniforms = new TextureUniforms;
	uniforms->fTexture = new TextureSampler();
	uniforms->fTexture->bind(new (memalign(64, sizeof(Surface))) Surface(128, 128, (void*) kBrickTexture));
	uniforms->fTexture->setEnableBilinearFiltering(true);
	context->uniforms = uniforms;
	context->numVertexParams = 6;
#endif

#if DRAW_TRIANGLE
	context->vertices = kTriangleVertices;
	context->numVertices = 3;
	context->indices = kTriangleIndices;
	context->numIndices = 3;
#elif DRAW_TORUS
	context->vertices = kTorusVertices;
	context->numVertices = kNumTorusVertices;
	context->indices = kTorusIndices;
	context->numIndices = kNumTorusIndices;
#elif DRAW_CUBE
	context->vertices = kCubeVertices;	
	context->numVertices = kNumCubeVertices;
	context->indices = kCubeIndices;
	context->numIndices = kNumCubeIndices;
#elif DRAW_TEAPOT
	context->vertices = kTeapotVertices;
	context->numVertices = kNumTeapotVertices;
	context->indices = kTeapotIndices;
	context->numIndices = kNumTeapotIndices;
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
		parallelExecuteAndSync(shadeVertices, context, (context->numVertices + 15) / 16, 1, 1);
		parallelExecuteAndSync(setUpTriangle, context, context->numIndices / 3, 1, 1);
		parallelExecuteAndSync(fillTile, context, kTilesPerRow, kTileRows, 1);
		modelViewMatrix = modelViewMatrix * rotationMatrix;
	}
	
	return 0;
}
