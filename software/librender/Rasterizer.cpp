// 
// Copyright 2011-2015 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 


//
// The basic approach is based on this article: 
// http://www.drdobbs.com/parallel/rasterization-on-larrabee/217200602
// Which in turn is derived from the paper "Hierarchical polygon tiling with 
// coverage masks" Proceedings of ACM SIGGRAPH 93, Ned Greene.
//

#include "Rasterizer.h"
#include "SIMDMath.h"

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

// Workhorse of rasterization.  Recursively subdivides tile into 4x4 grids.
void subdivideTile( 
	ShaderFiller &filler,
	const int acceptCornerValue1, 
	const int acceptCornerValue2, 
	const int acceptCornerValue3,
	const int rejectCornerValue1, 
	const int rejectCornerValue2,
	const int rejectCornerValue3,
	const veci16_t acceptStep1, 
	const veci16_t acceptStep2, 
	const veci16_t acceptStep3, 
	const veci16_t rejectStep1, 
	const veci16_t rejectStep2, 
	const veci16_t rejectStep3, 
	const int tileSize,
	const int tileLeft,
	const int tileTop,
	const int clipRight,
	const int clipBottom)
{
	// Compute accept masks
	const veci16_t acceptEdgeValue1 = acceptStep1 + splati(acceptCornerValue1);
	const veci16_t acceptEdgeValue2 = acceptStep2 + splati(acceptCornerValue2);
	const veci16_t acceptEdgeValue3 = acceptStep3 + splati(acceptCornerValue3);
	const int trivialAcceptMask = __builtin_nyuzi_mask_cmpi_sle(acceptEdgeValue1, splati(0))
		& __builtin_nyuzi_mask_cmpi_sle(acceptEdgeValue2, splati(0))
		& __builtin_nyuzi_mask_cmpi_sle(acceptEdgeValue3, splati(0));

	if (tileSize == 4)
	{
		// End recursion
		filler.fillMasked(tileLeft, tileTop, trivialAcceptMask);
		return;
	}

	const int subTileSize = tileSize / 4;

	// Process all trivially accepted blocks
	if (trivialAcceptMask != 0)
	{
		int currentMask = trivialAcceptMask;
	
		while (currentMask)
		{
			const int index = __builtin_clz(currentMask) - 16;
			currentMask &= ~(0x8000 >> index);
			const int subTileLeft = tileLeft + subTileSize * (index & 3);
			const int subTileTop = tileTop + subTileSize * (index >> 2);
			const int right = min(subTileSize, clipRight - subTileLeft);
			const int bottom = min(subTileSize, clipBottom - subTileTop);
			for (int y = 0; y < bottom; y += 4)
			{
				for (int x = 0; x < right; x += 4)
					filler.fillMasked(subTileLeft + x, subTileTop + y, 0xffff);
			}
		}
	}

	// Compute reject masks
	const veci16_t rejectEdgeValue1 = rejectStep1 + splati(rejectCornerValue1);
	const veci16_t rejectEdgeValue2 = rejectStep2 + splati(rejectCornerValue2);
	const veci16_t rejectEdgeValue3 = rejectStep3 + splati(rejectCornerValue3);
	const int trivialRejectMask = __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue1, splati(0))
		| __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue2, splati(0))
		| __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue3, splati(0));

	int recurseMask = (trivialAcceptMask | trivialRejectMask) ^ 0xffff;
	if (recurseMask)
	{
		// Divide each step matrix by 4
		const veci16_t subAcceptStep1 = acceptStep1 >> splati(2);	
		const veci16_t subAcceptStep2 = acceptStep2 >> splati(2);
		const veci16_t subAcceptStep3 = acceptStep3 >> splati(2);
		const veci16_t subRejectStep1 = rejectStep1 >> splati(2);
		const veci16_t subRejectStep2 = rejectStep2 >> splati(2);
		const veci16_t subRejectStep3 = rejectStep3 >> splati(2);

		// Recurse into blocks that are neither trivially rejected or accepted.
		// They are partially overlapped and need to be further subdivided.
		while (recurseMask)
		{
			const int index = __builtin_clz(recurseMask) - 16;
			recurseMask &= ~(0x8000 >> index);
			const int x = tileLeft + subTileSize * (index & 3);
			const int y = tileTop + subTileSize * (index >> 2);
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
				subAcceptStep1,
				subAcceptStep2,
				subAcceptStep3,
				subRejectStep1,
				subRejectStep2,
				subRejectStep3,
				subTileSize,
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
