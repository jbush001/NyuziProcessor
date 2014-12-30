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

using namespace librender;

void *operator new[](size_t size, void *p)
{
	return p;
}

RenderContext::RenderContext()
	: 	fRenderTarget(nullptr)
{
	fDrawQueue.setAllocator(&fAllocator);
}

void RenderContext::bindGeometry(const float *vertices, int numVertices, const int *indices, int numIndices)
{
	fCurrentState.fVertices = vertices;
	fCurrentState.fNumVertices = numVertices;
	fCurrentState.fIndices = indices;
	fCurrentState.fNumIndices = numIndices;
}

void RenderContext::bindUniforms(const void *uniforms)
{
	fCurrentState.fUniforms = uniforms;
}

void RenderContext::bindTarget(RenderTarget *target)
{
	fRenderTarget = target;
	fFbWidth = fRenderTarget->getColorBuffer()->getWidth();
	fFbHeight = fRenderTarget->getColorBuffer()->getHeight();
	fTileColumns = (fFbWidth + kTileSize - 1) / kTileSize;
	fTileRows = (fFbHeight + kTileSize - 1) / kTileSize;
}

void RenderContext::bindShader(VertexShader *vertexShader, PixelShader *pixelShader)
{
	fCurrentState.fVertexShader = vertexShader;
	fCurrentState.fPixelShader = pixelShader;
	fCurrentState.fNumVertexParams = fCurrentState.fVertexShader->getNumParams();
}

void RenderContext::submitDrawCommand()
{
	fDrawQueue.append(fCurrentState);
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

void RenderContext::finish()
{
	int kMaxTiles = fTileColumns * fTileRows;
	fTiles = new (fAllocator.alloc(kMaxTiles * sizeof(TriangleArray))) TriangleArray[kMaxTiles];
	for (int i = 0; i < kMaxTiles; i++)	
		fTiles[i].setAllocator(&fAllocator);

	for (fRenderCommandIndex = 0; fRenderCommandIndex < fDrawQueue.count(); fRenderCommandIndex++)
	{
		DrawCommand &command = fDrawQueue[fRenderCommandIndex];
		command.fVertexParams = (float*) fAllocator.alloc(command.fNumVertices 
			* command.fVertexShader->getNumParams() * sizeof(float));
		parallelSpawn(_shadeVertices, this, (command.fNumVertices + 15) / 16, 1, 1);
		parallelSpawn(_setUpTriangle, this, command.fNumIndices / 3, 1, 1);
		parallelJoin();
	}

	parallelSpawn(_fillTile, this, fTileColumns, fTileRows, 1);
	parallelJoin();
	fAllocator.reset();
	fDrawQueue.reset();
}

void RenderContext::shadeVertices(int index, int, int)
{
	DrawCommand &command = fDrawQueue[fRenderCommandIndex];
	int numVertices = command.fNumVertices - index * 16;
	if (numVertices > 16)
		numVertices = 16;
	
	command.fVertexShader->processVertices(command.fVertexParams + command.fVertexShader->getNumParams() 
		* index * 16, command.fVertices + command.fVertexShader->getNumAttribs() * index * 16, 
		command.fUniforms, numVertices);
}

void RenderContext::setUpTriangle(int triangleIndex, int, int)
{
	DrawCommand &command = fDrawQueue[fRenderCommandIndex];
	int vertexIndex = triangleIndex * 3;
	Triangle tri;
	tri.sequenceNumber = triangleIndex;
	tri.command = &command;
	tri.offset0 = command.fIndices[vertexIndex] * command.fNumVertexParams;
	tri.offset1 = command.fIndices[vertexIndex + 1] * command.fNumVertexParams;
	tri.offset2 = command.fIndices[vertexIndex + 2] * command.fNumVertexParams;
	tri.x0 = command.fVertexParams[tri.offset0 + kParamX];
	tri.y0 = command.fVertexParams[tri.offset0 + kParamY];
	tri.z0 = command.fVertexParams[tri.offset0 + kParamZ];
	tri.x1 = command.fVertexParams[tri.offset1 + kParamX];
	tri.y1 = command.fVertexParams[tri.offset1 + kParamY];
	tri.z1 = command.fVertexParams[tri.offset1 + kParamZ];
	tri.x2 = command.fVertexParams[tri.offset2 + kParamX];
	tri.y2 = command.fVertexParams[tri.offset2 + kParamY];
	tri.z2 = command.fVertexParams[tri.offset2 + kParamZ];
	
	// XXX clip
	
	// Perform perspective division
	float oneOverW0 = 1.0 / command.fVertexParams[tri.offset0 + kParamW];
	float oneOverW1 = 1.0 / command.fVertexParams[tri.offset1 + kParamW];
	float oneOverW2 = 1.0 / command.fVertexParams[tri.offset2 + kParamW];
	tri.x0 *= oneOverW0;
	tri.y0 *= oneOverW0;
	tri.x1 *= oneOverW1;
	tri.y1 *= oneOverW1;
	tri.x2 *= oneOverW2;
	tri.y2 *= oneOverW2;
	
	// Convert screen space coordinates to raster coordinates
	tri.x0Rast = tri.x0 * fFbWidth / 2 + fFbWidth / 2;
	tri.y0Rast = tri.y0 * fFbHeight / 2 + fFbHeight / 2;
	tri.x1Rast = tri.x1 * fFbWidth / 2 + fFbWidth / 2;
	tri.y1Rast = tri.y1 * fFbHeight / 2 + fFbHeight / 2;
	tri.x2Rast = tri.x2 * fFbWidth / 2 + fFbWidth / 2;
	tri.y2Rast = tri.y2 * fFbHeight / 2 + fFbHeight / 2;

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
		return;
	}
	
	// Compute bounding box
	int bbLeft = tri.x0Rast < tri.x1Rast ? tri.x0Rast : tri.x1Rast;
	bbLeft = tri.x2Rast < bbLeft ? tri.x2Rast : bbLeft;
	int bbTop = tri.y0Rast < tri.y1Rast ? tri.y0Rast : tri.y1Rast;
	bbTop = tri.y2Rast < bbTop ? tri.y2Rast : bbTop;
	int bbRight = tri.x0Rast > tri.x1Rast ? tri.x0Rast : tri.x1Rast;
	bbRight = tri.x2Rast > bbRight ? tri.x2Rast : bbRight;
	int bbBottom = tri.y0Rast > tri.y1Rast ? tri.y0Rast : tri.y1Rast;
	bbBottom = tri.y2Rast > bbBottom ? tri.y2Rast : bbBottom;	

	// Stuff in tile lists
	int minTileX = max(bbLeft / kTileSize, 0);
	int maxTileX = min(bbRight / kTileSize, fTileColumns - 1);
	int minTileY = max(bbTop / kTileSize, 0);
	int maxTileY = min(bbBottom / kTileSize, fTileRows - 1);
	for (int tiley = minTileY; tiley <= maxTileY; tiley++)
	{
		for (int tilex = minTileX; tilex <= maxTileX; tilex++)
			fTiles[tiley * fTileColumns + tilex].append(tri);
	}
}

void RenderContext::fillTile(int x, int y, int)
{
	const int tileX = x * kTileSize;
	const int tileY = y * kTileSize;
	TriangleArray &tile = fTiles[y * fTileColumns + x];
	Rasterizer rasterizer(fFbWidth, fFbHeight);
	ShaderFiller filler(fRenderTarget);
	
	tile.sort();

	Surface *colorBuffer = fRenderTarget->getColorBuffer();
	colorBuffer->clearTile(tileX, tileY, 0);

	// Initialize Z-Buffer to infinity
	fRenderTarget->getZBuffer()->clearTile(tileX, tileY, 0x7f800000);

	// Walk through triangles in this tile and render
	for (int index = 0; index < tile.count(); index++)
	{
		const Triangle &tri = tile[index];
		const DrawCommand &command = *tri.command;

#if WIREFRAME
		drawLineClipped(colorBuffer, tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, 0xffffffff,
			tileX, tileY, tileX + kTileSize, tileY + kTileSize);
		drawLineClipped(colorBuffer, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast, 0xffffffff,
			tileX, tileY, tileX + kTileSize, tileY + kTileSize);
		drawLineClipped(colorBuffer, tri.x2Rast, tri.y2Rast, tri.x0Rast, tri.y0Rast, 0xffffffff,
			tileX, tileY, tileX + kTileSize, tileY + kTileSize);
#else
		filler.setUniforms(command.fUniforms);
		filler.enableZBuffer(command.fEnableZBuffer);
		filler.setPixelShader(command.fPixelShader);
		filler.enableBlend(command.fEnableBlend);

		// Set up parameters and rasterize triangle.
		filler.setUpTriangle(tri.x0, tri.y0, tri.z0, tri.x1, tri.y1, tri.z1, tri.x2, 
			tri.y2, tri.z2);
		for (int paramI = 0; paramI < command.fNumVertexParams; paramI++)
		{
			filler.setUpParam(paramI, 
				command.fVertexParams[tri.offset0 + paramI + 4],
				command.fVertexParams[tri.offset1 + paramI + 4], 
				command.fVertexParams[tri.offset2 + paramI + 4]);
		}

		rasterizer.fillTriangle(filler, tileX, tileY,
			tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast);	
	}
#endif
	
	colorBuffer->flushTile(tileX, tileY);
}
