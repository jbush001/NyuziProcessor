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

namespace librender
{

class RenderContext
{
public:
	RenderContext();
	void bindTarget(RenderTarget *target);
	void bindShader(VertexShader *vertexShader, PixelShader *pixelShader);
	void bindGeometry(const float *vertices, int numVertices, const int *indices, int numIndices);
	void bindUniforms(const void *uniforms);
	
	void enableZBuffer(bool enabled)
	{
		fCurrentState.fEnableZBuffer = enabled;
	}
	
	bool isZBufferEnabled() const
	{
		return fCurrentState.fEnableZBuffer;
	}
	
	void enableBlend(bool enabled)
	{
		fCurrentState.fEnableBlend = enabled;
	}
	
	bool isBlendEnabled() const
	{
		return fCurrentState.fEnableBlend;
	}

	void submitDrawCommand();
	void finish();
		
private:
	struct DrawCommand
	{
		DrawCommand()
			:	fVertexParams(nullptr),
				fVertices(nullptr),
				fIndices(nullptr),
				fUniforms(nullptr)
		{}
		
		bool fEnableZBuffer;
		bool fEnableBlend;
		float *fVertexParams;
		const float *fVertices;
		int fNumVertices;
		const int *fIndices;
		int fNumIndices;
		const void *fUniforms;
		int fNumVertexParams;
		VertexShader *fVertexShader;	
		PixelShader *fPixelShader;
	};
	
	struct Triangle 
	{
		int sequenceNumber;
		DrawCommand *command;
		float x0, y0, z0, x1, y1, z1, x2, y2, z2;
		int x0Rast, y0Rast, x1Rast, y1Rast, x2Rast, y2Rast;
		float *params;
		bool operator>(const Triangle &tri) const
		{
			return sequenceNumber > tri.sequenceNumber;
		}
	};

	void shadeVertices(int index, int, int);
	void setUpTriangle(int triangleIndex, int, int);
	void fillTile(int x, int y, int);
	static void _shadeVertices(void *_castToContext, int x, int y, int z);
	static void _setUpTriangle(void *_castToContext, int x, int y, int z);
	static void _fillTile(void *_castToContext, int x, int y, int z);
	void clipOne(int sequence, DrawCommand &command, float *params0, float *params1,
		float *params2);
	void clipTwo(int sequence, DrawCommand &command, float *params0, float *params1,
		float *params2);
	void enqueueTriangle(int sequence, DrawCommand &command, const float *params0, 
		const float *params1, const float *params2);
	
	typedef SliceArray<Triangle, 32, 32> TriangleArray;
		
	RenderTarget *fRenderTarget;
	TriangleArray *fTiles;
	int fFbWidth;
	int fFbHeight;
	SliceAllocator fAllocator;
	int fTileColumns;
	int fTileRows;
	DrawCommand fCurrentState;
	SliceArray<DrawCommand, 32, 16> fDrawQueue;
	int fRenderCommandIndex;
	int fBaseSequenceNumber;
};

}

#endif
