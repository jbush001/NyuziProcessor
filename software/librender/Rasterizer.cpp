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

//
// The basic approach is based on this article: 
// http://www.drdobbs.com/parallel/rasterization-on-larrabee/217200602
// Which in turn is derived from the paper "Hierarchical polygon tiling with 
// coverage masks" Proceedings of ACM SIGGRAPH 93, Ned Greene.
//

#include "Rasterizer.h"
#include "RenderUtils.h"

using namespace librender;

namespace 
{

const veci16_t kXStep = { 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 };
const veci16_t kYStep = { 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 };

void setupEdge(int tileLeft, int tileTop, int x1, int y1, 
	int x2, int y2, int &outAcceptEdgeValue, int &outRejectEdgeValue, 
	veci16_t &outAcceptStepMatrix, veci16_t &outRejectStepMatrix)
{
	veci16_t xAcceptStepValues = kXStep * splati(kTileSize / 4);
	veci16_t yAcceptStepValues = kYStep * splati(kTileSize / 4);
	veci16_t xRejectStepValues = xAcceptStepValues;
	veci16_t yRejectStepValues = yAcceptStepValues;
	int trivialAcceptX = tileLeft;
	int trivialAcceptY = tileTop;
	int trivialRejectX = tileLeft;
	int trivialRejectY = tileTop;
	const int kThreeQuarterTile = kTileSize * 3 / 4;

	if (y2 > y1)
	{
		trivialAcceptX += kTileSize - 1;
		xAcceptStepValues = xAcceptStepValues - splati(kThreeQuarterTile);
	}
	else
	{
		trivialRejectX += kTileSize - 1;
		xRejectStepValues = xRejectStepValues - splati(kThreeQuarterTile);
	}

	if (x2 > x1)
	{
		trivialRejectY += kTileSize - 1;
		yRejectStepValues = yRejectStepValues - splati(kThreeQuarterTile);
	}
	else
	{
		trivialAcceptY += kTileSize - 1;
		yAcceptStepValues = yAcceptStepValues - splati(kThreeQuarterTile);
	}

	int xStep = y2 - y1;
	int yStep = x2 - x1;

	outAcceptEdgeValue = (trivialAcceptX - x1) * xStep - (trivialAcceptY - y1) * yStep;
	outRejectEdgeValue = (trivialRejectX - x1) * xStep - (trivialRejectY - y1) * yStep;

	if (y1 > y2 || (y1 == y2 && x2 > x1))
	{
		// This is a top or left edge.  We adjust the edge equation values by one
		// so it doesn't overlap (top left fill convention).
		outAcceptEdgeValue++;
		outRejectEdgeValue++;	
	}

	// Set up xStepValues
	xAcceptStepValues *= splati(xStep);
	xRejectStepValues *= splati(xStep);

	// Set up yStepValues
	yAcceptStepValues *= splati(yStep);
	yRejectStepValues *= splati(yStep);
	
	// Add together
	outAcceptStepMatrix = xAcceptStepValues - yAcceptStepValues;
	outRejectStepMatrix = xRejectStepValues - yRejectStepValues;
}

void subdivideTile( 
	ShaderFiller &filler,
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
	int tileLeft,
	int tileTop,
	int clipRight,
	int clipBottom)
{
	veci16_t acceptEdgeValue1;
	veci16_t acceptEdgeValue2;
	veci16_t acceptEdgeValue3;
	veci16_t rejectEdgeValue1;
	veci16_t rejectEdgeValue2;
	veci16_t rejectEdgeValue3;
	int trivialAcceptMask;
	int trivialRejectMask;
	int recurseMask;
	int index;
	int x, y;

	// Compute accept masks
	acceptEdgeValue1 = acceptStep1 + splati(acceptCornerValue1);
	trivialAcceptMask = __builtin_nyuzi_mask_cmpi_sle(acceptEdgeValue1, splati(0));
	acceptEdgeValue2 = acceptStep2 + splati(acceptCornerValue2);
	trivialAcceptMask &= __builtin_nyuzi_mask_cmpi_sle(acceptEdgeValue2, splati(0));
	acceptEdgeValue3 = acceptStep3 + splati(acceptCornerValue3);
	trivialAcceptMask &= __builtin_nyuzi_mask_cmpi_sle(acceptEdgeValue3, splati(0));

	if (tileSize == 4)
	{
		// End recursion
		filler.fillMasked(tileLeft, tileTop, trivialAcceptMask);
		return;
	}

	// Reduce tile size for sub blocks
	tileSize = tileSize / 4;

	// Process all trivially accepted blocks
	if (trivialAcceptMask != 0)
	{
		int index;
		int currentMask = trivialAcceptMask;
	
		while (currentMask)
		{
			index = __builtin_clz(currentMask) - 16;
			currentMask &= ~(0x8000 >> index);
			int subTileLeft = tileLeft + tileSize * (index & 3);
			int subTileTop = tileTop + tileSize * (index >> 2);
			int right = min(tileSize, clipRight - subTileLeft);
			int bottom = min(tileSize, clipBottom - subTileTop);
			for (int y = 0; y < bottom; y += 4)
			{
				for (int x = 0; x < right; x += 4)
					filler.fillMasked(subTileLeft + x, subTileTop + y, 0xffff);
			}
		}
	}

	// Compute reject masks
	rejectEdgeValue1 = rejectStep1 + splati(rejectCornerValue1);
	trivialRejectMask = __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue1, splati(0));
	rejectEdgeValue2 = rejectStep2 + splati(rejectCornerValue2);
	trivialRejectMask |= __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue2, splati(0));
	rejectEdgeValue3 = rejectStep3 + splati(rejectCornerValue3);
	trivialRejectMask |= __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue3, splati(0));

	recurseMask = (trivialAcceptMask | trivialRejectMask) ^ 0xffff;
	if (recurseMask)
	{
		// Divide each step matrix by 4
		acceptStep1 = acceptStep1 >> splati(2);	
		acceptStep2 = acceptStep2 >> splati(2);
		acceptStep3 = acceptStep3 >> splati(2);
		rejectStep1 = rejectStep1 >> splati(2);
		rejectStep2 = rejectStep2 >> splati(2);
		rejectStep3 = rejectStep3 >> splati(2);

		// Recurse into blocks that are neither trivially rejected or accepted.
		// They are partially overlapped and need to be further subdivided.
		while (recurseMask)
		{
			index = __builtin_clz(recurseMask) - 16;
			recurseMask &= ~(0x8000 >> index);
			x = tileLeft + tileSize * (index & 3);
			y = tileTop + tileSize * (index >> 2);
			if (x >= clipRight || y >= clipBottom)
				continue;	// Clip tiles that are outside viewport

			subdivideTile(
				filler,
				acceptEdgeValue1[index],
				acceptEdgeValue2[index],
				acceptEdgeValue3[index],
				rejectEdgeValue1[index],
				rejectEdgeValue2[index],
				rejectEdgeValue3[index],
				acceptStep1,
				acceptStep2,
				acceptStep3,
				rejectStep1,
				rejectStep2,
				rejectStep3,
				tileSize,
				x, 
				y,
				clipRight,
				clipBottom);			
		}
	}
}

}

void librender::fillTriangle(ShaderFiller &filler,
	int tileLeft, int tileTop, 
	int x1, int y1, int x2, int y2, int x3, int y3,
	int clipRight, int clipBottom)
{
	int acceptValue1;
	int rejectValue1;
	veci16_t acceptStepMatrix1;
	veci16_t rejectStepMatrix1;
	int acceptValue2;
	int rejectValue2;
	veci16_t acceptStepMatrix2;
	veci16_t rejectStepMatrix2;
	int acceptValue3;
	int rejectValue3;
	veci16_t acceptStepMatrix3;
	veci16_t rejectStepMatrix3;

	// This assumes counter-clockwise winding for triangles that are
	// facing the camera.
	setupEdge(tileLeft, tileTop, x1, y1, x3, y3, acceptValue1, rejectValue1, 
		acceptStepMatrix1, rejectStepMatrix1);
	setupEdge(tileLeft, tileTop, x3, y3, x2, y2, acceptValue2, rejectValue2, 
		acceptStepMatrix2, rejectStepMatrix2);
	setupEdge(tileLeft, tileTop, x2, y2, x1, y1, acceptValue3, rejectValue3, 
		acceptStepMatrix3, rejectStepMatrix3);

	subdivideTile(
		filler,
		acceptValue1,
		acceptValue2,
		acceptValue3,
		rejectValue1,
		rejectValue2,
		rejectValue3,
		acceptStepMatrix1,
		acceptStepMatrix2,
		acceptStepMatrix3,
		rejectStepMatrix1,
		rejectStepMatrix2,
		rejectStepMatrix3,
		kTileSize,
		tileLeft, 
		tileTop,
		clipRight,
		clipBottom);
}
