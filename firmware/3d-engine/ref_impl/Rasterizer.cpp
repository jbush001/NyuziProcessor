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

#include <stdio.h>
#include <string.h>
#include "Rasterizer.h"
#include "misc.h"
#include "vec16.h"

#define FB_SIZE 64
#define S0 0
#define S1 (FB_SIZE / 4)
#define S2 (FB_SIZE * 2 / 4)
#define S3 (FB_SIZE * 3 / 4)

const int kXSteps[] = { S0, S1, S2, S3, S0, S1, S2, S3, S0, S1, S2, S3, S0, S1, S2, S3 };
const int kYSteps[] = { S0, S0, S0, S0, S1, S1, S1, S1, S2, S2, S2, S2, S3, S3, S3, S3 };

Rasterizer::Rasterizer()
	:	fShaderState(NULL)
{
}

void Rasterizer::setupEdge(int left, int top, int x1, int y1, int x2, int y2, int &outAcceptEdgeValue, 
	int &outRejectEdgeValue, vec16<int> &outAcceptStepMatrix, vec16<int> &outRejectStepMatrix)
{
	vec16<int> xAcceptStepValues;
	vec16<int> yAcceptStepValues;
	vec16<int> xRejectStepValues;
	vec16<int> yRejectStepValues;
	int xStep;
	int yStep;
	int trivialAcceptX = left;
	int trivialAcceptY = top;
	int trivialRejectX = left;
	int trivialRejectY = top;

	xAcceptStepValues.load(kXSteps);
	xRejectStepValues.load(kXSteps);
	yAcceptStepValues.load(kYSteps);
	yRejectStepValues.load(kYSteps);

	if (y2 > y1)
	{
		trivialAcceptX += FB_SIZE - 1;
		xAcceptStepValues = xAcceptStepValues - S3;
	}
	else
	{
		trivialRejectX += FB_SIZE - 1;
		xRejectStepValues = xRejectStepValues - S3;
	}

	if (x2 > x1)
	{
		trivialRejectY += FB_SIZE - 1;
		yRejectStepValues = yRejectStepValues - S3;
	}
	else
	{
		trivialAcceptY += FB_SIZE - 1;
		yAcceptStepValues = yAcceptStepValues - S3;
	}

	xStep = y2 - y1;
	yStep = x2 - x1;

	outAcceptEdgeValue = (trivialAcceptX - x1) * xStep - (trivialAcceptY - y1) * yStep;
	outRejectEdgeValue = (trivialRejectX - x1) * xStep - (trivialRejectY - y1) * yStep;

	// Set up xStepValues
	xAcceptStepValues = xAcceptStepValues * xStep;
	xRejectStepValues = xRejectStepValues * xStep;

	// Set up yStepValues
	yAcceptStepValues = yAcceptStepValues * yStep;
	yRejectStepValues = yRejectStepValues * yStep;
	
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
	vec16<int> acceptStep1, 
	vec16<int> acceptStep2, 
	vec16<int> acceptStep3, 
	vec16<int> rejectStep1, 
	vec16<int> rejectStep2, 
	vec16<int> rejectStep3, 
	int tileSize,
	int left,
	int top)
{
	vec16<int> acceptEdgeValue1;
	vec16<int> acceptEdgeValue2;
	vec16<int> acceptEdgeValue3;
	vec16<int> rejectEdgeValue1;
	vec16<int> rejectEdgeValue2;
	vec16<int> rejectEdgeValue3;
	int trivialAcceptMask;
	int trivialRejectMask;
	int recurseMask;
	int index;
	int x, y;
	
#if 0
	printf("subdivideTile(%08x, %08x, %08x, %08x, %08x, %08x,\n",
		acceptCornerValue1, 
		acceptCornerValue2, 
		acceptCornerValue3,
		rejectCornerValue1, 
		rejectCornerValue2,
		rejectCornerValue3);
	acceptStep1.print(); printf("\n"); 
	acceptStep2.print(); printf("\n");
	acceptStep3.print(); printf("\n");
	rejectStep1.print(); printf("\n");
	rejectStep2.print(); printf("\n");
	rejectStep3.print(); printf("\n");
#endif

	// Compute accept masks
	acceptEdgeValue1 = acceptStep1 + acceptCornerValue1;
	trivialAcceptMask = acceptEdgeValue1 <= 0;
	acceptEdgeValue2 = acceptStep2 + acceptCornerValue2;
	trivialAcceptMask &= acceptEdgeValue2 <= 0;
	acceptEdgeValue3 = acceptStep3 + acceptCornerValue3;
	trivialAcceptMask &= acceptEdgeValue3 <= 0;

	if (tileSize == 4)
	{
		// End recursion
		fShaderState->fillMasked(left, top, trivialAcceptMask);
		return;
	}

	// Reduce tile size for sub blocks
	tileSize = tileSize / 4;

	// Process all trivially accepted blocks
	if (trivialAcceptMask != 0)
	{
		int index;
		int currentMask = trivialAcceptMask;
	
		while ((index = clz(currentMask)) >= 0)
		{			
			currentMask &= ~(1 << index);
			int blockLeft = left + tileSize * ((15 - index) & 3);
			int blockTop = top + tileSize * ((15 - index) >> 2);
			for (int y = 0; y < tileSize; y += 4)
			{
				for (int x = 0; x < tileSize; x += 4)
					fShaderState->fillMasked(blockLeft + x, blockTop + y, 0xffff);
			}
		}
	}
	
	// Compute reject masks
	rejectEdgeValue1 = rejectStep1 + rejectCornerValue1;
	trivialRejectMask = rejectEdgeValue1 >= 0;
	rejectEdgeValue2 = rejectStep2 + rejectCornerValue2;
	trivialRejectMask |= rejectEdgeValue2 >= 0;
	rejectEdgeValue3 = rejectStep3 + rejectCornerValue3;
	trivialRejectMask |= rejectEdgeValue3 >= 0;

	recurseMask = (trivialAcceptMask | trivialRejectMask) ^ 0xffff;
	if (recurseMask)
	{
		// Divide each step matrix by 4
		acceptStep1 = acceptStep1 >> 2;	
		acceptStep2 = acceptStep2 >> 2;
		acceptStep3 = acceptStep3 >> 2;
		rejectStep1 = rejectStep1 >> 2;
		rejectStep2 = rejectStep2 >> 2;
		rejectStep3 = rejectStep3 >> 2;

		// Recurse into blocks that are neither trivially rejected or accepted.
		while ((index = clz(recurseMask)) >= 0)
		{
			recurseMask &= ~(1 << index);
			x = left + tileSize * ((15 - index) & 3);
			y = top + tileSize * ((15 - index) >> 2);

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
				x, y);			
		}
	}
}

void Rasterizer::rasterizeTriangle(PixelShaderState *shaderState, 
	int binLeft, int binTop,
	int x1, int y1, int x2, int y2, int x3, int y3)
{
	int acceptValue1;
	int rejectValue1;
	vec16<int> acceptStepMatrix1;
	vec16<int> rejectStepMatrix1;
	int acceptValue2;
	int rejectValue2;
	vec16<int> acceptStepMatrix2;
	vec16<int> rejectStepMatrix2;
	int acceptValue3;
	int rejectValue3;
	vec16<int> acceptStepMatrix3;
	vec16<int> rejectStepMatrix3;

	fShaderState = shaderState;

	setupEdge(binLeft, binTop, x1, y1, x2, y2, acceptValue1, rejectValue1, acceptStepMatrix1, rejectStepMatrix1);
	setupEdge(binLeft, binTop, x2, y2, x3, y3, acceptValue2, rejectValue2, acceptStepMatrix2, rejectStepMatrix2);
	setupEdge(binLeft, binTop, x3, y3, x1, y1, acceptValue3, rejectValue3, acceptStepMatrix3, rejectStepMatrix3);

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
		FB_SIZE,
		binLeft, binTop);
}
