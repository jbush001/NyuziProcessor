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

//
// Rasterize a triangle by hierarchial subdivision
//

#include "Debug.h"
#include "Rasterizer.h"
#include "vectypes.h"

#define TILE_SIZE 64
#define S0 0
#define S1 (TILE_SIZE / 4)
#define S2 (TILE_SIZE * 2 / 4)
#define S3 (TILE_SIZE * 3 / 4)

const veci16 kXSteps = { S0, S1, S2, S3, S0, S1, S2, S3, S0, S1, S2, S3, S0, S1, S2, S3 };
const veci16 kYSteps = { S0, S0, S0, S0, S1, S1, S1, S1, S2, S2, S2, S2, S3, S3, S3, S3 };

Rasterizer::Rasterizer()
	:	fShader(0)
{
}

void Rasterizer::setupEdge(int left, int top, int x1, int y1, int x2, int y2, int &outAcceptEdgeValue, 
	int &outRejectEdgeValue, veci16 &outAcceptStepMatrix, veci16 &outRejectStepMatrix)
{
	veci16 xAcceptStepValues = kXSteps;
	veci16 yAcceptStepValues = kYSteps;
	veci16 xRejectStepValues = kXSteps;
	veci16 yRejectStepValues = kYSteps;
	int xStep;
	int yStep;
	int trivialAcceptX = left;
	int trivialAcceptY = top;
	int trivialRejectX = left;
	int trivialRejectY = top;

	if (y2 > y1)
	{
		trivialAcceptX += TILE_SIZE - 1;
		xAcceptStepValues = xAcceptStepValues - __builtin_vp_makevectori(S3);
	}
	else
	{
		trivialRejectX += TILE_SIZE - 1;
		xRejectStepValues = xRejectStepValues - __builtin_vp_makevectori(S3);
	}

	if (x2 > x1)
	{
		trivialRejectY += TILE_SIZE - 1;
		yRejectStepValues = yRejectStepValues - __builtin_vp_makevectori(S3);
	}
	else
	{
		trivialAcceptY += TILE_SIZE - 1;
		yAcceptStepValues = yAcceptStepValues - __builtin_vp_makevectori(S3);
	}

	xStep = y2 - y1;
	yStep = x2 - x1;

	outAcceptEdgeValue = (trivialAcceptX - x1) * xStep - (trivialAcceptY - y1) * yStep;
	outRejectEdgeValue = (trivialRejectX - x1) * xStep - (trivialRejectY - y1) * yStep;

	// Set up xStepValues
	xAcceptStepValues *= __builtin_vp_makevectori(xStep);
	xRejectStepValues *= __builtin_vp_makevectori(xStep);

	// Set up yStepValues
	yAcceptStepValues *= __builtin_vp_makevectori(yStep);
	yRejectStepValues *= __builtin_vp_makevectori(yStep);
	
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
	int left,
	int top)
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
	acceptEdgeValue1 = acceptStep1 + __builtin_vp_makevectori(acceptCornerValue1);
	trivialAcceptMask = __builtin_vp_mask_cmpi_sle(acceptEdgeValue1, __builtin_vp_makevectori(0));
	acceptEdgeValue2 = acceptStep2 + __builtin_vp_makevectori(acceptCornerValue2);
	trivialAcceptMask &= __builtin_vp_mask_cmpi_sle(acceptEdgeValue2, __builtin_vp_makevectori(0));
	acceptEdgeValue3 = acceptStep3 + __builtin_vp_makevectori(acceptCornerValue3);
	trivialAcceptMask &= __builtin_vp_mask_cmpi_sle(acceptEdgeValue3, __builtin_vp_makevectori(0));

	if (tileSize == 4)
	{
		// End recursion
		fShader->fillMasked(left, top, trivialAcceptMask);
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
			int blockLeft = left + tileSize * (index & 3);
			int blockTop = top + tileSize * (index >> 2);
			for (int y = 0; y < tileSize; y += 4)
			{
				for (int x = 0; x < tileSize; x += 4)
					fShader->fillMasked(blockLeft + x, blockTop + y, 0xffff);
			}
		}
	}
	
	// Compute reject masks
	rejectEdgeValue1 = rejectStep1 + __builtin_vp_makevectori(rejectCornerValue1);
	trivialRejectMask = __builtin_vp_mask_cmpi_sge(rejectEdgeValue1, __builtin_vp_makevectori(0));
	rejectEdgeValue2 = rejectStep2 + __builtin_vp_makevectori(rejectCornerValue2);
	trivialRejectMask |= __builtin_vp_mask_cmpi_sge(rejectEdgeValue2, __builtin_vp_makevectori(0));
	rejectEdgeValue3 = rejectStep3 + __builtin_vp_makevectori(rejectCornerValue3);
	trivialRejectMask |= __builtin_vp_mask_cmpi_sge(rejectEdgeValue3, __builtin_vp_makevectori(0));

	recurseMask = (trivialAcceptMask | trivialRejectMask) ^ 0xffff;
	if (recurseMask)
	{
		// Divide each step matrix by 4
		acceptStep1 = acceptStep1 >> __builtin_vp_makevectori(2);	
		acceptStep2 = acceptStep2 >> __builtin_vp_makevectori(2);
		acceptStep3 = acceptStep3 >> __builtin_vp_makevectori(2);
		rejectStep1 = rejectStep1 >> __builtin_vp_makevectori(2);
		rejectStep2 = rejectStep2 >> __builtin_vp_makevectori(2);
		rejectStep3 = rejectStep3 >> __builtin_vp_makevectori(2);

		// Recurse into blocks that are neither trivially rejected or accepted.
		while (recurseMask)
		{
			index = __builtin_clz(recurseMask) - 16;
			recurseMask &= ~(0x8000 >> index);
			x = left + tileSize * (index & 3);
			y = top + tileSize * (index >> 2);

			// Partially overlapped parts need to be further subdivided
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
	int binLeft, int binTop,
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

	setupEdge(binLeft, binTop, x1, y1, x2, y2, acceptValue1, rejectValue1, 
		acceptStepMatrix1, rejectStepMatrix1);
	setupEdge(binLeft, binTop, x2, y2, x3, y3, acceptValue2, rejectValue2, 
		acceptStepMatrix2, rejectStepMatrix2);
	setupEdge(binLeft, binTop, x3, y3, x1, y1, acceptValue3, rejectValue3, 
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
		TILE_SIZE,
		binLeft, 
		binTop);
}
