// 
// Copyright 2011-2013 Jeff Bush
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

#include "Debug.h"
#include "Rasterizer.h"
#include "vectypes.h"

const veci16 kXStep = { 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 };
const veci16 kYStep = { 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 };

Rasterizer::Rasterizer()
	:	fShader(nullptr)
{
}

void Rasterizer::setupEdge(int tileLeft, int tileTop, int x1, int y1, 
	int x2, int y2, int &outAcceptEdgeValue, int &outRejectEdgeValue, 
	veci16 &outAcceptStepMatrix, veci16 &outRejectStepMatrix)
{
	veci16 xAcceptStepValues = kXStep * splati(kTileSize / 4);
	veci16 yAcceptStepValues = kYStep * splati(kTileSize / 4);
	veci16 xRejectStepValues = xAcceptStepValues;
	veci16 yRejectStepValues = yAcceptStepValues;
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

void Rasterizer::subdivideTile( 
	int acceptCornerValue1, 
	int acceptCornerValue2, 
	int acceptCornerValue3,
	int rejectCornerValue1, 
	int rejectCornerValue2,
	int rejectCornerValue3,
	veci16 acceptStep1, 
	veci16 acceptStep2, 
	veci16 acceptStep3, 
	veci16 rejectStep1, 
	veci16 rejectStep2, 
	veci16 rejectStep3, 
	int tileSize,
	int tileLeft,
	int tileTop)
{
	veci16 acceptEdgeValue1;
	veci16 acceptEdgeValue2;
	veci16 acceptEdgeValue3;
	veci16 rejectEdgeValue1;
	veci16 rejectEdgeValue2;
	veci16 rejectEdgeValue3;
	int trivialAcceptMask;
	int trivialRejectMask;
	int recurseMask;
	int index;
	int x, y;

	// Compute accept masks
	acceptEdgeValue1 = acceptStep1 + splati(acceptCornerValue1);
	trivialAcceptMask = __builtin_vp_mask_cmpi_sle(acceptEdgeValue1, splati(0));
	acceptEdgeValue2 = acceptStep2 + splati(acceptCornerValue2);
	trivialAcceptMask &= __builtin_vp_mask_cmpi_sle(acceptEdgeValue2, splati(0));
	acceptEdgeValue3 = acceptStep3 + splati(acceptCornerValue3);
	trivialAcceptMask &= __builtin_vp_mask_cmpi_sle(acceptEdgeValue3, splati(0));

	if (tileSize == 4)
	{
		// End recursion
		fShader->fillMasked(tileLeft, tileTop, trivialAcceptMask);
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
			for (int y = 0; y < tileSize; y += 4)
			{
				for (int x = 0; x < tileSize; x += 4)
					fShader->fillMasked(subTileLeft + x, subTileTop + y, 0xffff);
			}
		}
	}
	
	// Compute reject masks
	rejectEdgeValue1 = rejectStep1 + splati(rejectCornerValue1);
	trivialRejectMask = __builtin_vp_mask_cmpi_sgt(rejectEdgeValue1, splati(0));
	rejectEdgeValue2 = rejectStep2 + splati(rejectCornerValue2);
	trivialRejectMask |= __builtin_vp_mask_cmpi_sgt(rejectEdgeValue2, splati(0));
	rejectEdgeValue3 = rejectStep3 + splati(rejectCornerValue3);
	trivialRejectMask |= __builtin_vp_mask_cmpi_sgt(rejectEdgeValue3, splati(0));

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

			subdivideTile(
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
				y);			
		}
	}
}

void Rasterizer::rasterizeTriangle(PixelShader *shader, 
	int tileLeft, int tileTop, 
	int x1, int y1, int x2, int y2, int x3, int y3)
{
	int acceptValue1;
	int rejectValue1;
	veci16 acceptStepMatrix1;
	veci16 rejectStepMatrix1;
	int acceptValue2;
	int rejectValue2;
	veci16 acceptStepMatrix2;
	veci16 rejectStepMatrix2;
	int acceptValue3;
	int rejectValue3;
	veci16 acceptStepMatrix3;
	veci16 rejectStepMatrix3;

	fShader = shader;

	setupEdge(tileLeft, tileTop, x1, y1, x2, y2, acceptValue1, rejectValue1, 
		acceptStepMatrix1, rejectStepMatrix1);
	setupEdge(tileLeft, tileTop, x2, y2, x3, y3, acceptValue2, rejectValue2, 
		acceptStepMatrix2, rejectStepMatrix2);
	setupEdge(tileLeft, tileTop, x3, y3, x1, y1, acceptValue3, rejectValue3, 
		acceptStepMatrix3, rejectStepMatrix3);

	subdivideTile(
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
		tileTop);
}
