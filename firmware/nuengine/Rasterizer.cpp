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

#define NEW_HW_RAST

Rasterizer::Rasterizer()
	:	fShader(nullptr)
{
}

void Rasterizer::setupEdge(int left, int top, int x1, int y1, 
	int x2, int y2, int &outAcceptEdgeValue, int &outRejectEdgeValue, 
	veci16 &outAcceptStepMatrix, veci16 &outRejectStepMatrix)
{
	veci16 xAcceptStepValues = kXStep * splati(kTileSize / 4);
	veci16 yAcceptStepValues = kYStep * splati(kTileSize / 4);
	veci16 xRejectStepValues = xAcceptStepValues;
	veci16 yRejectStepValues = yAcceptStepValues;
	int trivialAcceptX = left;
	int trivialAcceptY = top;
	int trivialRejectX = left;
	int trivialRejectY = top;
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
		// so it doesn't overlap.
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
	acceptEdgeValue1 = acceptStep1 + splati(acceptCornerValue1);
	trivialAcceptMask = __builtin_vp_mask_cmpi_sle(acceptEdgeValue1, splati(0));
	acceptEdgeValue2 = acceptStep2 + splati(acceptCornerValue2);
	trivialAcceptMask &= __builtin_vp_mask_cmpi_sle(acceptEdgeValue2, splati(0));
	acceptEdgeValue3 = acceptStep3 + splati(acceptCornerValue3);
	trivialAcceptMask &= __builtin_vp_mask_cmpi_sle(acceptEdgeValue3, splati(0));

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
			x = left + tileSize * (index & 3);
			y = top + tileSize * (index >> 2);

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

#ifdef OLD_SW_RAST
void Rasterizer::rasterizeTriangle(PixelShader *shader, 
	int left, int top, 
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

	setupEdge(left, top, x1, y1, x2, y2, acceptValue1, rejectValue1, 
		acceptStepMatrix1, rejectStepMatrix1);
	setupEdge(left, top, x2, y2, x3, y3, acceptValue2, rejectValue2, 
		acceptStepMatrix2, rejectStepMatrix2);
	setupEdge(left, top, x3, y3, x1, y1, acceptValue3, rejectValue3, 
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
		left, 
		top);
}
#endif

volatile unsigned int* const HWBASE = (volatile unsigned int*) 0xffff0400;


enum HwReadRegs
{
	// Read address space
	kRegStatus = 0,
	kRegMask,
	kRegPatchX,
	kRegPatchY,
	kRegAction = 6,
	kRegEnable
};

//int total_loops = 0;
//int total_fills = 0;

inline
void Rasterizer::RenderTrap()
{
	HWBASE[kRegEnable] = 1;
	int s;
	while ((s=HWBASE[kRegStatus]) & 2) {
		if (s&1) {
			int x, y, m;
			x = HWBASE[kRegPatchX];
			y = HWBASE[kRegPatchY];
			m = HWBASE[kRegMask];
			HWBASE[kRegAction] = 1;
			fShader->fillMasked(x, y, m);
			//total_fills++;
		}
		//total_loops++;
	}
	HWBASE[kRegEnable] = 0;
	
	//Debug::debug << total_fills << " / " << total_loops << "\n";
}

#ifdef OLD_HW_RAST
enum HwRegs
{
	// Write address space
	kRegX1 = 0,
	kRegX2,
	kRegDX1,
	kRegDX2,
	kRegY,
	kRegHeight,
	kRegActionX,
	kRegEnableX,
	kRegClipLeft,
	kRegClipRight
};


template <T>
inline swap(T& a, T& b) {
	T c;
	c = a;
	a = b;
	b = c;
}


void Rasterizer::rasterizeTriangle(PixelShader *shader, 
	int left, int top, int tileSize, 
	int x1, int y1, int x2, int y2, int x3, int y3)
{
	int h;
	fShader = shader;

	HWBASE[kRegClipLeft] = -32768;
	HWBASE[kRegClipRight] = 32767;
    HWBASE[kRegEnable] = 0;
	
	// Bubble sort points top to bottom
	for (;;) {
		bool again = false;
		if (y1 > y2) {
			swap(y1, y2);
			swap(x1, x2);
			again = true;
		}
		if (y2 > y3) {
			swap(y2, y3);
			swap(x2, x3);
			again = true;
		}
		if (!again) break;
	}
	
	// What is the x coordinate of y2 on line <x1,y1>-<x3,y3> ?
	double t = (double)(y2 - y1) / (double)(y3 - y1);
	double x2b = t * (x3 - x1) + x1;
	
	if (x2 > x2b) {
		// Knee on right
		
		// Top
		h = y2 - y1;
		if (h > 0) {
			HWBASE[kRegX1] = HWBASE[kRegX2] = x1<<16;
			HWBASE[kRegDX1] = 65536 * (x3 - x1) / (y3 - y1);
			HWBASE[kRegDX2] = 65536 * (x2 - x1) / (y2 - y1);
			HWBASE[kRegY] = y1;
			HWBASE[kRegHeight] = h;
			RenderTrap();
		}

		// Bottom
		// (Theoretically, we should only have to change the right edge slope, but I think 
		// that the rendering engine won't recalculate patch_x correctly.)
		h = y3 - y2;
		if (h > 0) {
			HWBASE[kRegX1] = (int)(x2b * 65536);
			HWBASE[kRegX2] = x2<<16;
			//HWBASE[kRegDX1] = 65536 * (x3 - x1) / (y3 - y1);
			HWBASE[kRegDX2] = 65536 * (x3 - x2) / (y3 - y2);
			HWBASE[kRegY] = y2;
			HWBASE[kRegHeight] = h;
			RenderTrap();
		}
	} else {
		// Knee on left
		
		// Top
		h = y2 - y1;
		if (h > 0) {
			HWBASE[kRegX1] = HWBASE[kRegX2] = x1<<16;
			HWBASE[kRegDX1] = 65536 * (x2 - x1) / (y2 - y1);
			HWBASE[kRegDX2] = 65536 * (x3 - x1) / (y3 - y1);
			HWBASE[kRegY] = y1;
			HWBASE[kRegHeight] = h;
			RenderTrap();
		}

		// Bottom
		h = y3 - y2;
		if (h > 0) {
			HWBASE[kRegX1] = x2<<16;
			HWBASE[kRegX2] = (int)(x2b * 65536);
			HWBASE[kRegDX1] = 65536 * (x3 - x2) / (y3 - y2);
			//HWBASE[kRegDX2] = 65536 * (x3 - x1) / (y3 - y1);
			HWBASE[kRegY] = y2;
			HWBASE[kRegHeight] = h;
			RenderTrap();
		}
	}
}
#endif


#ifdef NEW_HW_RAST
enum HwRegs
{
	// Write address space
	kRegX1 = 0,
	kRegY1,
	kRegX2,
	kRegY2,
	kRegX3,
	kRegY3,
	kRegActionX,
	kRegEnableX,
	kRegClipLeft,
	kRegClipTop,
	kRegClipRight,
	kRegClipBot,
	kRegClipEnable
};

void Rasterizer::rasterizeTriangle(PixelShader *shader, 
	int left, int top, int tileSize, 
	int x1, int y1, int x2, int y2, int x3, int y3)
{
	HWBASE[kRegClipLeft] = left;
	HWBASE[kRegClipTop] = top;
	HWBASE[kRegClipRight] = left + tileSize - 1;
	HWBASE[kRegClipBot] = top + tileSize - 1;
	HWBASE[kRegClipEnable] = 1;

	fShader = shader;

	// Clipping is implicitly disabled.  If we have a screen-aligned box,
	// we can turn it on.
	
	HWBASE[kRegX1] = x1 << 16;
	HWBASE[kRegY1] = y1 << 16;
	HWBASE[kRegX2] = x2 << 16;
	HWBASE[kRegY2] = y2 << 16;
	HWBASE[kRegX3] = x3 << 16;
	HWBASE[kRegY3] = y3 << 16;
	RenderTrap();
}
#endif
