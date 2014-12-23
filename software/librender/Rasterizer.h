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


#ifndef __RASTERIZER_H
#define __RASTERIZER_H

#include <stdint.h>
#include "PixelShader.h"

namespace render
{

//
// The basic approach is based on this article: 
// http://www.drdobbs.com/parallel/rasterization-on-larrabee/217200602
// Which in turn is derived from the paper "Hierarchical polygon tiling with 
// coverage masks" Proceedings of ACM SIGGRAPH 93, Ned Greene.
//

class Filler
{
public:
	virtual void fillMasked(int left, int top, unsigned short mask) = 0;
};

class Rasterizer
{
public:
	// maxX and maxY must be a multiple of four
	Rasterizer(int maxX, int maxY);
	
	// Triangles are wound counter-clockwise
	void fillTriangle(Filler &filler,
		int left, int top,
		int x1, int y1, int x2, int y2, int x3, int y3);

private:
	void setupEdge(int left, int top, int x1, int y1, int x2, int y2, 
		int &outAcceptEdgeValue, int &outRejectEdgeValue, veci16_t &outAcceptStepMatrix, 
		veci16_t &outRejectStepMatrix);
	void subdivideTile( 
		Filler &filler,
		int acceptCornerValue1, 
		int acceptCornerValue2, 
		int acceptCornerValue3,
		int rejectCornerValue1, 
		int rejectCornerValue2,
		int rejectCornerValue3,
		veci16_t acceptStep1, 
		veci16_t acceptStep2, 
		veci16_t acceptStep3, 
		veci16_t rejectStep1, 
		veci16_t rejectStep2, 
		veci16_t rejectStep3, 
		int tileSize,
		int left,
		int top);

	int fClipRight;
	int fClipBottom;
};

}

#endif
