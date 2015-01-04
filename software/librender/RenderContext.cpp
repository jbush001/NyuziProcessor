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

#include <string.h>
#include <schedule.h>
#include <string.h>
#include "RenderContext.h"
#include "Rasterizer.h"
#include "line.h"
#include "ShaderFiller.h"
#include "RenderUtils.h"

#define WIREFRAME 0

using namespace librender;

void *operator new[](size_t, void *p)
{
	return p;
}

RenderContext::RenderContext()
{
	fDrawQueue.setAllocator(&fAllocator);
	::memset(&fCurrentState, 0, sizeof(fCurrentState));
}

void RenderContext::setClearColor(float r, float g, float b)
{
	r = max(min(r, 1.0f), 0.0f);
	g = max(min(g, 1.0f), 0.0f);
	b = max(min(b, 1.0f), 0.0f);

	fClearColor = 0xff000000 | (int(b * 255.0) << 16) | (int(g * 255.0) << 8) | int(r * 255.0);
}

void RenderContext::bindGeometry(const float *vertices, int numVertices, const int *indices, int numIndices)
{
	fCurrentState.fVertices = vertices;
	fCurrentState.fNumVertices = numVertices;
	fCurrentState.fIndices = indices;
	fCurrentState.fNumIndices = numIndices;
}

void RenderContext::bindUniforms(const void *uniforms, size_t size)
{
	void *uniformCopy = fAllocator.alloc(size);
	::memcpy(uniformCopy, uniforms, size);
	fCurrentState.fUniforms = uniformCopy;
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

void RenderContext::_shadeVertices(void *_castToContext, int x, int, int)
{
	static_cast<RenderContext*>(_castToContext)->shadeVertices(x);
}

void RenderContext::_setUpTriangle(void *_castToContext, int x, int, int)
{
	static_cast<RenderContext*>(_castToContext)->setUpTriangle(x);
}

void RenderContext::_fillTile(void *_castToContext, int x, int y, int)
{
	static_cast<RenderContext*>(_castToContext)->fillTile(x, y);
}

void RenderContext::_wireframeTile(void *_castToContext, int x, int y, int)
{
	static_cast<RenderContext*>(_castToContext)->wireframeTile(x, y);
}

void RenderContext::finish()
{
	int kMaxTiles = fTileColumns * fTileRows;
	fTiles = new (fAllocator.alloc(kMaxTiles * sizeof(TriangleArray))) TriangleArray[kMaxTiles];
	for (int i = 0; i < kMaxTiles; i++)	
		fTiles[i].setAllocator(&fAllocator);

	fBaseSequenceNumber = 0;
	for (fRenderCommandIterator = fDrawQueue.begin(); fRenderCommandIterator != fDrawQueue.end(); 
		++fRenderCommandIterator)
	{
		DrawState &command = *fRenderCommandIterator;
		command.fVertexParams = (float*) fAllocator.alloc(command.fNumVertices 
			* command.fVertexShader->getNumParams() * sizeof(float));
		parallelSpawn(_shadeVertices, this, (command.fNumVertices + 15) / 16, 1, 1);
		int numTriangles = command.fNumIndices / 3;
		parallelSpawn(_setUpTriangle, this, numTriangles, 1, 1);
		parallelJoin();
		fBaseSequenceNumber += command.fNumIndices / 3;
	}

	if (fWireframeMode)
		parallelSpawn(_wireframeTile, this, fTileColumns, fTileRows, 1);
	else
		parallelSpawn(_fillTile, this, fTileColumns, fTileRows, 1);

	parallelJoin();

#if DISPLAY_STATS
	printf("total triangles = %d\n", fBaseSequenceNumber);
	printf("used %d bytes\n", fAllocator.bytesUsed()); 
#endif
	
	// First reset draw queue to clean up, then allocator, which will pull
	// memory out beneath it
	fDrawQueue.reset();
	fAllocator.reset();
}

void RenderContext::shadeVertices(int index)
{
	DrawState &command = *fRenderCommandIterator;
	int numVertices = command.fNumVertices - index * 16;
	if (numVertices > 16)
		numVertices = 16;
	
	command.fVertexShader->processVertices(command.fVertexParams + command.fVertexShader->getNumParams() 
		* index * 16, command.fVertices + command.fVertexShader->getNumAttribs() * index * 16, 
		command.fUniforms, numVertices);
}

namespace {

const float kNearZClip = -1.0;

void interpolate(float *outParams, const float *inParams0, const float *inParams1, int numParams, 
	float distance)
{
	for (int i = 0; i < numParams; i++)
		outParams[i] = inParams0[i] * (1.0 - distance) + inParams1[i] * distance;
}

}

//
// The clipped vertex will always be params0.  This will create two new triangles above
// the clip plane.
//
//    1 +-------+ 2
//      | \    /
//      |   \ /
//  np1 +----+ np2
//      |.../
//      |../    clipped
//      |./
//      |/
//      0
//

void RenderContext::clipOne(int sequence, DrawState &command, float *params0, float *params1,
	float *params2)
{
	float newPoint1[kMaxParams];
	float newPoint2[kMaxParams];
	
	interpolate(newPoint1, params1, params0, command.fNumVertexParams, (params1[kParamZ] - kNearZClip)
		/ (params1[kParamZ] - params0[kParamZ]));
	interpolate(newPoint2, params2, params0, command.fNumVertexParams, (params2[kParamZ] - kNearZClip)
		/ (params2[kParamZ] - params0[kParamZ]));
	enqueueTriangle(sequence, command, newPoint1, params1, newPoint2);
	enqueueTriangle(sequence, command, newPoint2, params1, params2);
}

//
// Two clipped vertices, which will always be param0 and params1
// This just adjusts the current triangle.
//
//                 2
//                 +  
//               / |
//              /  |
//             /   |
//        np1 +----+ np2
//           /.....|
//          /......|  clipped
//         /.......|
//        +--------+
//        1        0
//

void RenderContext::clipTwo(int sequence, DrawState &command, float *params0, float *params1,
	float *params2)
{
	float newPoint1[kMaxParams];
	float newPoint2[kMaxParams];

	interpolate(newPoint1, params2, params1, command.fNumVertexParams, (params2[kParamZ] - kNearZClip)
		/ (params2[kParamZ] - params1[kParamZ]));
	interpolate(newPoint2, params2, params0, command.fNumVertexParams, (params2[kParamZ] - kNearZClip)
		/ (params2[kParamZ] - params0[kParamZ]));
	enqueueTriangle(sequence, command, newPoint2, newPoint1, params2);
}

void RenderContext::setUpTriangle(int triangleIndex)
{
	DrawState &command = *fRenderCommandIterator;
	int vertexIndex = triangleIndex * 3;
	int offset0 = command.fIndices[vertexIndex] * command.fNumVertexParams;
	int offset1 = command.fIndices[vertexIndex + 1] * command.fNumVertexParams;
	int offset2 = command.fIndices[vertexIndex + 2] * command.fNumVertexParams;
	float *params0 = &command.fVertexParams[offset0];
	float *params1 = &command.fVertexParams[offset1];
	float *params2 = &command.fVertexParams[offset2];

	// Determine which point (if any) are clipped, call appropriate clip routine
	// with triangle rotated appropriately.
	int clipMask = (params0[kParamZ] > kNearZClip ? 1 : 0) | (params1[kParamZ] > kNearZClip ? 2 : 0)
		| (params2[kParamZ] > kNearZClip ? 4 : 0);
	switch (clipMask)
	{
		case 0:
			// Not clipped at all.
			enqueueTriangle(fBaseSequenceNumber + triangleIndex, command, 
				params0, params1, params2);
			break;

		case 1:
			clipOne(fBaseSequenceNumber + triangleIndex, command, params0, params1, params2);
			break;

		case 2:
			clipOne(fBaseSequenceNumber + triangleIndex, command, params1, params2, params0);
			break;
			
		case 4:
			clipOne(fBaseSequenceNumber + triangleIndex, command, params2, params0, params1);
			break;

		case 3:
			clipTwo(fBaseSequenceNumber + triangleIndex, command, params0, params1, params2);
			break;

		case 6:
			clipTwo(fBaseSequenceNumber + triangleIndex, command, params1, params2, params0);
			break;
			
		case 5:
			clipTwo(fBaseSequenceNumber + triangleIndex, command, params2, params0, params1);
			break;

		// Else is totally clipped, ignore
	}
}

void RenderContext::enqueueTriangle(int sequence, DrawState &command, const float *params0, 
	const float *params1, const float *params2)
{	
	Triangle tri;
	tri.sequenceNumber = sequence;
	tri.command = &command;

	// Perform perspective division
	float oneOverW0 = 1.0 / fabs_f(params0[kParamW]);
	float oneOverW1 = 1.0 / fabs_f(params1[kParamW]);
	float oneOverW2 = 1.0 / fabs_f(params2[kParamW]);
	tri.x0 = params0[kParamX] * oneOverW0;
	tri.y0 = params0[kParamY] * oneOverW0;
	tri.z0 = params0[kParamZ];
	tri.x1 = params1[kParamX] * oneOverW1;
	tri.y1 = params1[kParamY] * oneOverW1;
	tri.z1 = params1[kParamZ];
	tri.x2 = params2[kParamX] * oneOverW2;
	tri.y2 = params2[kParamY] * oneOverW2;
	tri.z2 = params2[kParamZ];
	
	// Convert screen space coordinates to raster coordinates
	int halfWidth = fFbWidth / 2;
	int halfHeight = fFbHeight / 2;
	tri.x0Rast = tri.x0 * halfWidth + halfWidth;
	tri.y0Rast = -tri.y0 * halfHeight + halfHeight;
	tri.x1Rast = tri.x1 * halfWidth + halfWidth;
	tri.y1Rast = -tri.y1 * halfHeight + halfHeight;
	tri.x2Rast = tri.x2 * halfWidth + halfWidth;
	tri.y2Rast = -tri.y2 * halfHeight + halfHeight;
	
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

	// Copy parameters into triangle structure, skipping position which is already
	// in x0/y0/z0/x1...
	int paramSize = sizeof(float) * (command.fNumVertexParams - 4);
	tri.params = (float*) fAllocator.alloc(paramSize * 3);
	memcpy(tri.params, params0 + 4, paramSize);
	memcpy(tri.params + command.fNumVertexParams - 4, params1 + 4, paramSize);
	memcpy(tri.params + (command.fNumVertexParams - 4) * 2, params2 + 4, paramSize);
	
	// Compute bounding box
	int bbLeft = tri.x0Rast < tri.x1Rast ? tri.x0Rast : tri.x1Rast;
	bbLeft = tri.x2Rast < bbLeft ? tri.x2Rast : bbLeft;
	int bbTop = tri.y0Rast < tri.y1Rast ? tri.y0Rast : tri.y1Rast;
	bbTop = tri.y2Rast < bbTop ? tri.y2Rast : bbTop;
	int bbRight = tri.x0Rast > tri.x1Rast ? tri.x0Rast : tri.x1Rast;
	bbRight = tri.x2Rast > bbRight ? tri.x2Rast : bbRight;
	int bbBottom = tri.y0Rast > tri.y1Rast ? tri.y0Rast : tri.y1Rast;
	bbBottom = tri.y2Rast > bbBottom ? tri.y2Rast : bbBottom;	

	// Determine which tiles this triangle may overlap with a simple
	// bounding box check.  Enqueue it in the queues for each tile.
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

void RenderContext::fillTile(int x, int y)
{
	const int tileX = x * kTileSize;
	const int tileY = y * kTileSize;
	TriangleArray &tile = fTiles[y * fTileColumns + x];
	Rasterizer rasterizer(fFbWidth, fFbHeight);
	Surface *colorBuffer = fRenderTarget->getColorBuffer();

	colorBuffer->clearTile(tileX, tileY, fClearColor);

	// Initialize Z-Buffer to -infinity
	if (fRenderTarget->getZBuffer())
		fRenderTarget->getZBuffer()->clearTile(tileX, tileY, 0xff800000);

	// Walk through triangles in this tile and render
	tile.sort();
	for (const Triangle &tri : tile)
	{
		ShaderFiller filler(tri.command, fRenderTarget);
		const DrawState &command = *tri.command;

		// Set up parameters and rasterize triangle.
		filler.setUpTriangle(tri.x0, tri.y0, tri.z0, tri.x1, tri.y1, tri.z1, tri.x2, 
			tri.y2, tri.z2);
		for (int paramI = 0; paramI < command.fNumVertexParams; paramI++)
		{
			filler.setUpParam(paramI, 
				tri.params[paramI],
				tri.params[(command.fNumVertexParams - 4) + paramI], 
				tri.params[(command.fNumVertexParams - 4) * 2 + paramI]);
		}

		rasterizer.fillTriangle(filler, tileX, tileY,
			tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast);	
	}
	
	colorBuffer->flushTile(tileX, tileY);
}

void RenderContext::wireframeTile(int x, int y)
{
	const int tileX = x * kTileSize;
	const int tileY = y * kTileSize;
	TriangleArray &tile = fTiles[y * fTileColumns + x];

	Surface *colorBuffer = fRenderTarget->getColorBuffer();
	colorBuffer->clearTile(tileX, tileY, fClearColor);
	int bottomClip = tileY + kTileSize - 1;
	int rightClip = tileX + kTileSize - 1;
	if (bottomClip >= colorBuffer->getHeight())
		bottomClip = colorBuffer->getHeight() - 1;
	
	if (rightClip >= colorBuffer->getWidth())
		rightClip = colorBuffer->getWidth() - 1;

	for (const Triangle &tri : tile)
	{
		drawLineClipped(colorBuffer, tri.x0Rast, tri.y0Rast, tri.x1Rast, tri.y1Rast, 0xffffffff,
			tileX, tileY, rightClip, bottomClip);
		drawLineClipped(colorBuffer, tri.x1Rast, tri.y1Rast, tri.x2Rast, tri.y2Rast, 0xffffffff,
			tileX, tileY, rightClip, bottomClip);
		drawLineClipped(colorBuffer, tri.x2Rast, tri.y2Rast, tri.x0Rast, tri.y0Rast, 0xffffffff,
			tileX, tileY, rightClip, bottomClip);
	}
	
	colorBuffer->flushTile(tileX, tileY);
}