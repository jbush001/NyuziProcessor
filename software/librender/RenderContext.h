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

#ifndef __RENDER_CONTEXT_H
#define __RENDER_CONTEXT_H

#include "RenderTarget.h"
#include "VertexShader.h"
#include "PixelShader.h"
#include "SliceAllocator.h"
#include "SliceArray.h"
#include "DrawState.h"

namespace librender
{

//
// Main interface for client applications to enqueue rendering commands.
//
class RenderContext
{
public:
	RenderContext(unsigned int workingMemSize = 0x400000);
	RenderContext(const RenderContext&) = delete;
	RenderContext& operator=(const RenderContext&) = delete;

	void setClearColor(float r, float g, float b);
	void bindTarget(RenderTarget *target);
	void bindShader(VertexShader *vertexShader, PixelShader *pixelShader);
	void bindGeometry(const float *vertices, int numVertices, const int *indices, int numIndices);
	void bindTexture(int textureIndex, Texture *texture)
	{
		fCurrentState.fTextures[textureIndex] = texture;
	}

	// XXX Unlike other state changes, this will be invalidated when finish() is called.
	void bindUniforms(const void *uniforms, size_t size);
	
	void enableZBuffer(bool enabled)
	{
		fCurrentState.fEnableZBuffer = enabled;
	}
	
	void enableBlend(bool enabled)
	{
		fCurrentState.fEnableBlend = enabled;
	}

	void submitDrawCommand();
	void finish();

	void enableWireframeMode(bool enable)
	{
		fWireframeMode = enable;
	}

	void setCulling(DrawState::CullingMode mode)
	{
		fCurrentState.cullingMode = mode;
	}
		
private:
	struct Triangle 
	{
		int sequenceNumber;
		const DrawState *state;
		float x0, y0, z0, x1, y1, z1, x2, y2, z2;
		int x0Rast, y0Rast, x1Rast, y1Rast, x2Rast, y2Rast;
		float *params;
		bool woundCCW;
		bool operator>(const Triangle &tri) const
		{
			return sequenceNumber > tri.sequenceNumber;
		}
	};

	void shadeVertices(int index);
	void setUpTriangle(int triangleIndex);
	void fillTile(int x, int y);
	void wireframeTile(int x, int y);
	static void _shadeVertices(void *_castToContext, int x, int y, int z);
	static void _setUpTriangle(void *_castToContext, int x, int y, int z);
	static void _fillTile(void *_castToContext, int x, int y, int z);
	static void _wireframeTile(void *_castToContext, int x, int y, int z);
	void clipOne(int sequence, const DrawState &command, const float *params0, const float *params1,
		const float *params2);
	void clipTwo(int sequence, const DrawState &command, const float *params0, const float *params1,
		const float *params2);
	void enqueueTriangle(int sequence, const DrawState &command, const float *params0, 
		const float *params1, const float *params2);
	
	typedef SliceArray<Triangle, 64> TriangleArray;
	typedef SliceArray<DrawState, 32> DrawQueue;
		
	RenderTarget *fRenderTarget = nullptr;
	TriangleArray *fTiles = nullptr;
	int fFbWidth = 0;
	int fFbHeight = 0;
	int fTileColumns = 0;
	int fTileRows = 0;
	SliceAllocator fAllocator;
	DrawState fCurrentState;
	DrawQueue fDrawQueue;
	DrawQueue::iterator fRenderCommandIterator = fDrawQueue.end();
	int fBaseSequenceNumber = 0;
	unsigned int fClearColor = 0xff000000;
	bool fWireframeMode = false;
};

}

#endif
