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

#include "RenderContext.h"
#include "Rasterizer.h"
#include "line.h"
#include "ShaderFiller.h"
#include <schedule.h>

#define WIREFRAME 0

const int kMaxVertices = 0x10000;
const int kMaxTriangles = 4096;

using namespace render;

RenderContext::RenderContext(RenderTarget *target)
	: 	fVertexParams(new float[kMaxVertices]),
		fTriangles(new Triangle[kMaxTriangles]),
		fRenderTarget(target),
		fFbWidth(target->getColorBuffer()->getWidth()),
		fFbHeight(target->getColorBuffer()->getHeight()),
		fUniforms(nullptr),
		fEnableZBuffer(false),
		fEnableBlend(false)
{
}

void RenderContext::bindGeometry(const float *vertices, int numVertices, const int *indices, int numIndices)
{
	fVertices = vertices;
	fNumVertices = numVertices;
	fIndices = indices;
	fNumIndices = numIndices;
}

void RenderContext::bindUniforms(const void *uniforms)
{
	fUniforms = uniforms;
}

void RenderContext::_shadeVertices(void *_castToContext, int x, int y, int z)
{
	static_cast<RenderContext*>(_castToContext)->shadeVertices(x, y, z);
}

void RenderContext::_setUpTriangle(void *_castToContext, int x, int y, int z)
{
	static_cast<RenderContext*>(_castToContext)->setUpTriangle(x, y, z);
}

void RenderContext::_fillTile(void *_castToContext, int x, int y, int z)
{
	static_cast<RenderContext*>(_castToContext)->fillTile(x, y, z);
}

void RenderContext::renderFrame()
{
	const int kTilesPerRow = (fFbWidth + kTileSize - 1) / kTileSize;
	const int kTileRows = (fFbHeight + kTileSize - 1) / kTileSize;

	parallelExecuteAndSync(_shadeVertices, this, (fNumVertices + 15) / 16, 1, 1);
	parallelExecuteAndSync(_setUpTriangle, this, fNumIndices / 3, 1, 1);
	parallelExecuteAndSync(_fillTile, this, kTilesPerRow, kTileRows, 1);
}

void RenderContext::bindShader(VertexShader *vertexShader, PixelShader *pixelShader)
{
	fVertexShader = vertexShader;
	fPixelShader = pixelShader;
	fNumVertexParams = fVertexShader->getNumParams();
}

void RenderContext::shadeVertices(int index, int, int)
{
	int numVertices = fNumVertices - index * 16;
	if (numVertices > 16)
		numVertices = 16;
	
	fVertexShader->processVertices(fVertexParams + fVertexShader->getNumParams() 
		* index * 16, fVertices + fVertexShader->getNumAttribs() * index * 16, 
		fUniforms, numVertices);
}

void RenderContext::setUpTriangle(int triangleIndex, int, int)
{
	int vertexIndex = triangleIndex * 3;

	Triangle &tri = fTriangles[triangleIndex];
	tri.offset0 = fIndices[vertexIndex] * fNumVertexParams;
	tri.offset1 = fIndices[vertexIndex + 1] * fNumVertexParams;
	tri.offset2 = fIndices[vertexIndex + 2] * fNumVertexParams;
	tri.x0 = fVertexParams[tri.offset0 + kParamX];
	tri.y0 = fVertexParams[tri.offset0 + kParamY];
	tri.z0 = fVertexParams[tri.offset0 + kParamZ];
	tri.x1 = fVertexParams[tri.offset1 + kParamX];
	tri.y1 = fVertexParams[tri.offset1 + kParamY];
	tri.z1 = fVertexParams[tri.offset1 + kParamZ];
	tri.x2 = fVertexParams[tri.offset2 + kParamX];
	tri.y2 = fVertexParams[tri.offset2 + kParamY];
	tri.z2 = fVertexParams[tri.offset2 + kParamZ];
	
	// Convert screen space coordinates to raster coordinates
	tri.x0Rast = tri.x0 * fFbWidth / 2 + fFbWidth / 2;
	tri.y0Rast = tri.y0 * fFbHeight / 2 + fFbHeight / 2;
	tri.x1Rast = tri.x1 * fFbWidth / 2 + fFbWidth / 2;
	tri.y1Rast = tri.y1 * fFbHeight / 2 + fFbHeight / 2;
	tri.x2Rast = tri.x2 * fFbWidth / 2 + fFbWidth / 2;
	tri.y2Rast = tri.y2 * fFbHeight / 2 + fFbHeight / 2;

	// Backface cull fTriangles that are facing away from camera.
	// This is an optimization: the rasterizer will not render 
	// fTriangles that are not facing the camera because of the way
	// the edge equations are computed. This avoids having to 
	// initialize the rasterizer unnecessarily.
	// However, this also removes fTriangles that are edge-on, 
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

void RenderContext::fillTile(int x, int y, int)
{
	int tileX = x * kTileSize;
	int tileY = y * kTileSize;
	Rasterizer rasterizer(fFbWidth, fFbHeight);
	ShaderFiller filler(fRenderTarget, fPixelShader);
	filler.setUniforms(fUniforms);
	filler.enableZBuffer(fEnableZBuffer);
	filler.enableBlend(fEnableBlend);
	
	int numTriangles = fNumIndices / 3;
	Surface *colorBuffer = fRenderTarget->getColorBuffer();

	colorBuffer->clearTile(tileX, tileY, 0);

	// Initialize Z-Buffer to infinity
	fRenderTarget->getZBuffer()->clearTile(tileX, tileY, 0x7f800000);

	// Cycle through all fTriangles and attempt to render into this 
	// NxN tile.
	for (int triangleIndex = 0; triangleIndex < numTriangles; triangleIndex++)
	{
		Triangle &tri = fTriangles[triangleIndex];
		if (!tri.visible)
			continue;

		// Bounding box check.  If fTriangles are not within this tile,
		// skip them.
		int xMax = tileX + kTileSize;
		int yMax = tileY + kTileSize;
		if (tri.bbRight < tileX || tri.bbBottom < tileY || tri.bbLeft > xMax
			|| tri.bbTop > yMax)
			continue;
		
#if WIREFRAME
		drawLine(colorBuffer, tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, 0xffffffff);
		drawLine(colorBuffer, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast, 0xffffffff);
		drawLine(colorBuffer, tri.x2Rast, tri.y2Rast, tri.x0Rast, tri.y0Rast, 0xffffffff);
#else
		// Set up parameters and rasterize triangle.
		filler.setUpTriangle(tri.x0, tri.y0, tri.z0, tri.x1, tri.y1, tri.z1, tri.x2, 
			tri.y2, tri.z2);
		for (int paramI = 0; paramI < fNumVertexParams; paramI++)
		{
			filler.setUpParam(paramI, 
				fVertexParams[tri.offset0 + paramI + 4],
				fVertexParams[tri.offset1 + paramI + 4], 
				fVertexParams[tri.offset2 + paramI + 4]);
		}

		rasterizer.fillTriangle(filler, tileX, tileY,
			tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast);	
#endif
	}
	
	colorBuffer->flushTile(tileX, tileY);
}