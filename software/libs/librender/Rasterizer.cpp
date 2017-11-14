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
// And is also described in "Hierarchical polygon tiling with coverage 
// masks" Proceedings of ACM SIGGRAPH 93, Ned Greene.
//

#include "Rasterizer.h"
#include "SIMDMath.h"

using namespace librender;

namespace 
{

#ifdef SWRAST
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
	TriangleFiller &filler,
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
	const int tileSizeBits,	// log2 tile size (1 << tileSizeBits = pixels)
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

#if 0
	// Compute reject masks
	const veci16_t rejectEdgeValue1 = rejectStep1 + splati(rejectCornerValue1);
	const veci16_t rejectEdgeValue2 = rejectStep2 + splati(rejectCornerValue2);
	const veci16_t rejectEdgeValue3 = rejectStep3 + splati(rejectCornerValue3);
	const int trivialRejectMask = __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue1, splati(0))
		| __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue2, splati(0))
		| __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue3, splati(0));
if (trivialAcceptMask & trivialRejectMask)
printf("Level %d: %d,%d: ac=%02X, rj=%02X\n", tileSizeBits, tileLeft, tileTop, trivialAcceptMask, trivialRejectMask);
#endif

	if (tileSizeBits == 2)
	{
		// End recursion
		if (trivialAcceptMask)
			filler.fillMasked(tileLeft, tileTop, trivialAcceptMask);
		//if (trivialRejectMask != 0xffff)
			//filler.fillMasked(tileLeft, tileTop, 0xffff ^ trivialRejectMask);

		return;
	}

	const int subTileSizeBits = tileSizeBits - 2;

#if 1
	// Process all trivially accepted blocks
	if (trivialAcceptMask != 0)
	{
		int currentMask = trivialAcceptMask;
	
		while (currentMask)
		{
			const int index = __builtin_clz(currentMask) - 16;
			currentMask &= ~(0x8000 >> index);
			const int subTileLeft = tileLeft + ((index & 3) << subTileSizeBits);
			const int subTileTop = tileTop + ((index >> 2) << subTileSizeBits);
			const int tileCount = 1 << subTileSizeBits;
			const int hcount = min(tileCount, clipRight - subTileLeft);
			const int vcount = min(tileCount, clipBottom - subTileTop);
			for (int y = 0; y < vcount; y += 4)
			{
				for (int x = 0; x < hcount; x += 4)
					filler.fillMasked(subTileLeft + x, subTileTop + y, 0xffff);
			}
		}
	}
#endif

#if 1
	// Compute reject masks
	const veci16_t rejectEdgeValue1 = rejectStep1 + splati(rejectCornerValue1);
	const veci16_t rejectEdgeValue2 = rejectStep2 + splati(rejectCornerValue2);
	const veci16_t rejectEdgeValue3 = rejectStep3 + splati(rejectCornerValue3);
	const int trivialRejectMask = __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue1, splati(0))
		| __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue2, splati(0))
		| __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue3, splati(0));
#endif

#if 0
	if (tileSizeBits == 2)
	{
		// End recursion
		if (trivialRejectMask != 0xffff)
			filler.fillMasked(tileLeft, tileTop, !trivialRejectMask);

		return;
	}
#endif

	// Recurse into blocks that are neither trivially rejected or accepted.
	// They are partially overlapped and need to be further subdivided.
	int recurseMask = (trivialAcceptMask | trivialRejectMask) ^ 0xffff;
	//int recurseMask = (trivialRejectMask) ^ 0xffff;
	if (recurseMask)
	{
		// Divide each step matrix by 4
		const veci16_t subAcceptStep1 = acceptStep1 >> splati(2);	
		const veci16_t subAcceptStep2 = acceptStep2 >> splati(2);
		const veci16_t subAcceptStep3 = acceptStep3 >> splati(2);
		const veci16_t subRejectStep1 = rejectStep1 >> splati(2);
		const veci16_t subRejectStep2 = rejectStep2 >> splati(2);
		const veci16_t subRejectStep3 = rejectStep3 >> splati(2);

		while (recurseMask)
		{
			const int index = __builtin_clz(recurseMask) - 16;
			recurseMask &= ~(0x8000 >> index);
			const int x = tileLeft + ((index & 3) << subTileSizeBits);
			const int y = tileTop + ((index >> 2) << subTileSizeBits);
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
				subTileSizeBits,
				x, 
				y,
				clipRight,
				clipBottom);			
		}
	}
}
#endif

}

#ifdef SWRAST
void librender::fillTriangle(TriangleFiller &filler,
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
		__builtin_ctz(kTileSize),
		tileLeft, 
		tileTop,
		clipRight,
		clipBottom);
}
void librender::printIdleTimes() {}
#endif

#ifdef SWRAST2
static inline
void setupLine(int tileX, int tileY, int x1, int y1, int x2, int y2, int& A, int& B, int& C)
{
    int bias = (y1<y2) || ((y1==y2) && (x2<x1));
    A = y2-y1;
    B = x2-x1;
    C = B*(y1-tileY) - A*(x1-tileX) - bias;
}

static inline
void box_minmax(int tileX, int x1, int x2, int x3, int& l, int& r)
{
    tileX >>= 2;
    x1 >>= 2;
    x2 >>= 2;
    x3 >>= 2;
    int left = tileX & ~15;
    int right = tileX | 15;

    int min = x1;
    if (x2 < min) min = x2;
    if (x3 < min) min = x3;
    if (right < min) min = right;
    if (left > min) min = left;
    min -= left;
    l = min;

    int max = x1;
    if (x2 > max) max = x2;
    if (x3 > max) max = x3;
    if (left > max) max = left;
    if (right < max) max = right;
    max -= left;
    r = max;
}


const veci16_t kXStep = { 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 };
const veci16_t kYStep = { 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 };

void librender::fillTriangle(TriangleFiller &filler,
	int tileLeft, int tileTop, 
	int x1, int y1, int x2, int y2, int x3, int y3,
	int clipRight, int clipBottom)
{
    int left, right, top, bot;
    int A[3], B[3], C[3];

    box_minmax(tileLeft, x1, x2, x3, left, right);
    box_minmax(tileTop, y1, y2, y3, top, bot);
    left = tileLeft + (left<<2);
    right = tileLeft + (right<<2);
    top = tileTop + (top<<2);
    bot = tileTop + (bot<<2);
    setupLine(left, top, x1, y1, x2, y2, A[0], B[0], C[0]);
    setupLine(left, top, x2, y2, x3, y3, A[1], B[1], C[1]);
    setupLine(left, top, x3, y3, x1, y1, A[2], B[2], C[2]);

    veci16_t Bstep[3], Astep[3], Cvec[3], Dvec[3];
    Dvec[0] = Cvec[0] = splati(C[0]) + splati(A[0])*kXStep - splati(B[0])*kYStep;
    Dvec[1] = Cvec[1] = splati(C[1]) + splati(A[1])*kXStep - splati(B[1])*kYStep;
    Dvec[2] = Cvec[2] = splati(C[2]) + splati(A[2])*kXStep - splati(B[2])*kYStep;
    Astep[0] = splati(A[0] << 2);
    Astep[1] = splati(A[1] << 2);
    Astep[2] = splati(A[2] << 2);
    Bstep[0] = splati(B[0] << 2);
    Bstep[1] = splati(B[1] << 2);
    Bstep[2] = splati(B[2] << 2);
    
    int patch_x, patch_y;
    for (patch_y=top; patch_y<=bot; patch_y+=4) {
        for (patch_x=left; patch_x<=right; patch_x+=4) {
            int mask = __builtin_nyuzi_mask_cmpi_sge(Dvec[0], splati(0))
                    & __builtin_nyuzi_mask_cmpi_sge(Dvec[1], splati(0))
                    & __builtin_nyuzi_mask_cmpi_sge(Dvec[2], splati(0));
            if (mask) {
			    filler.fillMasked(patch_x, patch_y, mask);
            }

            Dvec[0] += Astep[0];
            Dvec[1] += Astep[1];
            Dvec[2] += Astep[2];
        }
        Dvec[0] = Cvec[0] = Cvec[0] - Bstep[0];
        Dvec[1] = Cvec[1] = Cvec[1] - Bstep[1];
        Dvec[2] = Cvec[2] = Cvec[2] - Bstep[2];
    }
}
void librender::printIdleTimes(){}
#endif


#ifdef HWRAST3
enum HwReadRegs
{
    kRegPatchXY = 0,
    kRegStatus = 2,
    kRegIdle = 4,
    kRegBusy = 5,
    kRegPatchXYAdv = 8,
    kRegStatusAdv = 10
};

enum HwRegs
{
    kRegTileXY = 0,
    kRegAB1 = 1,
    kRegC1 = 2,
    kRegAB2 = 3,
    kRegC2 = 4,
    kRegAB3 = 5,
    kRegC3 = 6,
    kRegLRTB = 7,
    kRegTileXYLd = 9,
    kRegAB1Ld = 9,
    kRegC1Ld = 10,
    kRegAB2Ld = 11,
    kRegC2Ld = 12,
    kRegAB3Ld = 13,
    kRegC3Ld = 14,
    kRegLRTBLd = 15
};

void librender::printIdleTimes()
{
    int idle[4], busy[4];
    idle[0] = *(volatile unsigned int*)(0xffff0100 + kRegIdle*4);
    idle[1] = *(volatile unsigned int*)(0xffff0100 + 64 + kRegIdle*4);
    idle[2] = *(volatile unsigned int*)(0xffff0100 + 128 + kRegIdle*4);
    idle[3] = *(volatile unsigned int*)(0xffff0100 + 192 + kRegIdle*4);
    busy[0] = *(volatile unsigned int*)(0xffff0100 + kRegBusy*4);
    busy[1] = *(volatile unsigned int*)(0xffff0100 + 64 + kRegBusy*4);
    busy[2] = *(volatile unsigned int*)(0xffff0100 + 128 + kRegBusy*4);
    busy[3] = *(volatile unsigned int*)(0xffff0100 + 192 + kRegBusy*4);
    printf("Idle: %d %d %d %d\n", idle[0], idle[1], idle[2], idle[3]);
    printf("Busy: %d %d %d %d\n", busy[0], busy[1], busy[2], busy[3]);
    int total, idles, busys;
    idles = idle[0] + idle[1] + idle[2] + idle[3];
    busys = busy[0] + busy[1] + busy[2] + busy[3];
    total = idles + busys;
    printf("Scalability:  %d/%d = %f\n", total, busys, (float)total / (float)busys);
}

void librender::setupTileClipping(int tileLeft, int tileTop, int clipRight, int clipBottom)
{
    int thread = __builtin_nyuzi_read_control_reg(0);
    volatile unsigned int* const HWBASE = (volatile unsigned int*)(0xffff0100 + (thread<<6));
    HWBASE[kRegTileXY] = (tileLeft & 0xffff) | (tileTop << 16);
}

static inline
void setupLine(volatile unsigned int *p, int tileX, int tileY, int x1, int y1, int x2, int y2)
{
    //printf("%d,%d - %d,%d\n", x1, y1, x2, y2);
    int bias = (y1<y2) || ((y1==y2) && (x2<x1));
    int A = y2-y1;
    int B = x2-x1;
    int C = B*(y1-tileY) - A*(x1-tileX) - bias;
    //printf("A=%d, B=%d, C=%d\n", A, B, C);
    p[0] = (A<<16) | (B & 0xffff);
    p[1] = C;
}

static inline
void box_minmax(int tileX, int x1, int x2, int x3, int& l, int& r)
{
//printf("A\n");
    tileX >>= 2;
    x1 >>= 2;
    x2 >>= 2;
    x3 >>= 2;
    int left = tileX & ~15;
    int right = tileX | 15;

//printf("B\n");
    int min = x1;
    if (x2 < min) min = x2;
    if (x3 < min) min = x3;
    if (right < min) min = right;
    if (left > min) min = left;
    min -= left;
    l = min;

//printf("C\n");
    int max = x1;
    if (x2 > max) max = x2;
    if (x3 > max) max = x3;
    if (left > max) max = left;
    if (right < max) max = right;
    max -= left;
    r = max;
//printf("min=%d, max=%d\n", min, max);
}

void librender::fillTriangle(TriangleFiller &filler,
    int tileLeft, int tileTop,
    int x1, int y1, int x2, int y2, int x3, int y3,
    int clipRight, int clipBottom)
{
    int thread = __builtin_nyuzi_read_control_reg(0);
    volatile unsigned int* const HWBASE = (volatile unsigned int*)(0xffff0100 + (thread<<6));

    int left, right, top, bot;
 
    box_minmax(tileLeft, x1, x2, x3, left, right);
    //printf("D\n");
    box_minmax(tileTop, y1, y2, y3, top, bot);
    //printf("D\n");
    tileLeft += left<<2;
    tileTop += top<<2;
    setupLine(HWBASE+kRegAB1, tileLeft, tileTop, x1, y1, x2, y2);
    setupLine(HWBASE+kRegAB2, tileLeft, tileTop, x2, y2, x3, y3);
    setupLine(HWBASE+kRegAB3, tileLeft, tileTop, x3, y3, x1, y1);
    HWBASE[kRegLRTBLd] = (left<<12) | (right<<8) | (top<<4) | bot;

    int s, t;
    while ((t=(s=HWBASE[kRegStatus])>>16) != 1) {
        //printf("s=%08x\n", s);
        if (t == 2) {
            int x, y;
            x = HWBASE[kRegPatchXYAdv];
            y = x >> 16;
            x = x & 0xffff;
            //y = HWBASE[kRegPatchY];
            //m = HWBASE[kRegMaskAdv];
            //printf("mask %d,%d=%x\n", x, y, m);
            if (x < clipRight && y < clipBottom)
			    filler.fillMasked(x, y, s & 0xffff);
            //s &= 0xffff;
			//if (s) filler.fillMasked(x & 0xffff, x >> 16, s);
            //fills++;
            //total_fills++;
        }
        //total_loops++;
    }
    //if (fills==0)
    //printf("Triangle (%d,%d) %d,%d %d,%d %d,%d\n", tileLeft, tileTop, x1, y1, x2, y2, x3, y3);
}
#endif


#ifdef HWRAST2
enum HwReadRegs
{
    kRegPatchX = 0,
    kRegPatchY = 1,
    kRegMask = 2,
    kRegStatus = 3,
    kRegIdle = 4,
    kRegBusy = 5,
    kRegTrian = 6,
    kRegPatch = 7,
    kRegPatchXAdv = 8,
    kRegPatchYAdv = 9,
    kRegMaskAdv = 10,
    kRegStatusAdv = 11,
};

enum HwRegs
{
    kRegTileX = 0,
    kRegTileY,
    kRegX1,
    kRegY1,
    kRegX2,
    kRegY2,
    kRegX3,
    kRegY3,
    kRegTileXLd = 8,
    kRegTileYLd,
    kRegX1Ld,
    kRegY1Ld,
    kRegX2Ld,
    kRegY2Ld,
    kRegX3Ld,
    kRegY3Ld,
};

void librender::printIdleTimes()
{
    int idle[4], busy[4], trian[4], patch[4];
    idle[0] = *(volatile unsigned int*)(0xffff0100 + kRegIdle*4);
    idle[1] = *(volatile unsigned int*)(0xffff0100 + 64 + kRegIdle*4);
    idle[2] = *(volatile unsigned int*)(0xffff0100 + 128 + kRegIdle*4);
    idle[3] = *(volatile unsigned int*)(0xffff0100 + 192 + kRegIdle*4);
    busy[0] = *(volatile unsigned int*)(0xffff0100 + kRegBusy*4);
    busy[1] = *(volatile unsigned int*)(0xffff0100 + 64 + kRegBusy*4);
    busy[2] = *(volatile unsigned int*)(0xffff0100 + 128 + kRegBusy*4);
    busy[3] = *(volatile unsigned int*)(0xffff0100 + 192 + kRegBusy*4);
    trian[0] = *(volatile unsigned int*)(0xffff0100 + kRegTrian*4);
    trian[1] = *(volatile unsigned int*)(0xffff0100 + 64 + kRegTrian*4);
    trian[2] = *(volatile unsigned int*)(0xffff0100 + 128 + kRegTrian*4);
    trian[3] = *(volatile unsigned int*)(0xffff0100 + 192 + kRegTrian*4);
    patch[0] = *(volatile unsigned int*)(0xffff0100 + kRegPatch*4);
    patch[1] = *(volatile unsigned int*)(0xffff0100 + 64 + kRegPatch*4);
    patch[2] = *(volatile unsigned int*)(0xffff0100 + 128 + kRegPatch*4);
    patch[3] = *(volatile unsigned int*)(0xffff0100 + 192 + kRegPatch*4);
    printf("Idle: %d %d %d %d\n", idle[0], idle[1], idle[2], idle[3]);
    printf("Busy: %d %d %d %d\n", busy[0], busy[1], busy[2], busy[3]);
    printf("Trian: %d %d %d %d\n", trian[0], trian[1], trian[2], trian[3]);
    printf("Patch: %d %d %d %d\n", patch[0], patch[1], patch[2], patch[3]);
    int total, idles, busys;
    idles = idle[0] + idle[1] + idle[2] + idle[3];
    busys = busy[0] + busy[1] + busy[2] + busy[3];
    total = idles + busys;
    printf("Scalability:  %d/%d = %f\n", total, busys, (float)total / (float)busys);
}

void librender::setupTileClipping(int tileLeft, int tileTop, int clipRight, int clipBottom)
{
    int thread = __builtin_nyuzi_read_control_reg(0);
    volatile unsigned int* const HWBASE = (volatile unsigned int*)(0xffff0100 + (thread<<6));
    //HWBASE[kRegTileX] = tileLeft;
    //HWBASE[kRegTileY] = tileTop;
    HWBASE[kRegTileX] = (tileLeft & 0xffff) | (tileTop << 16);
}

void librender::fillTriangle(TriangleFiller &filler,
    int tileLeft, int tileTop,
    int x1, int y1, int x2, int y2, int x3, int y3,
    int clipRight, int clipBottom)
{
    int thread = __builtin_nyuzi_read_control_reg(0);
    volatile unsigned int* const HWBASE = (volatile unsigned int*)(0xffff0100 + (thread<<6));
    int fills = 0;

    //HWBASE[kRegTileX] = tileLeft;
    //HWBASE[kRegTileY] = tileTop;
    //printf("Triangle (%d,%d) %d,%d %d,%d %d,%d\n", tileLeft, tileTop, x1, y1, x2, y2, x3, y3);
    /*HWBASE[kRegX1] = x1;
    HWBASE[kRegY1] = y1;
    HWBASE[kRegX2] = x2;
    HWBASE[kRegY2] = y2;
    HWBASE[kRegX3] = x3;
    HWBASE[kRegY3Ld] = y3;*/
    //HWBASE[kRegTileX] = (tileLeft & 0xffff) | (tileTop << 16);
    HWBASE[kRegX1] = (x1 & 0xffff) | (y1 << 16);
    HWBASE[kRegX2] = (x2 & 0xffff) | (y2 << 16);
    HWBASE[kRegX3Ld] = (x3 & 0xffff) | (y3 << 16);

    int s, t;
    while ((t=(s=HWBASE[kRegMask])>>16) != 1) {
        //printf("s=%08x\n", s);
        if (t == 2) {
            int x, y, m;
            x = HWBASE[kRegPatchXAdv];
            //y = HWBASE[kRegPatchY];
            //m = HWBASE[kRegMaskAdv];
            //printf("mask %d,%d=%x\n", x, y, m);
			filler.fillMasked(x & 0xffff, x >> 16, s & 0xffff);
            //fills++;
            //total_fills++;
        }
        //total_loops++;
    }
    //if (fills==0)
    //printf("Triangle (%d,%d) %d,%d %d,%d %d,%d\n", tileLeft, tileTop, x1, y1, x2, y2, x3, y3);
}
#endif

#ifdef HWRAST
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


void librender::setupTileClipping(int tileLeft, int tileTop, int clipRight, int clipBottom)
{
    int thread = __builtin_nyuzi_read_control_reg(0);
    volatile unsigned int* const HWBASE = (volatile unsigned int*)(0xffff0100 + (thread<<6));
    HWBASE[kRegClipLeft] = tileLeft;
    HWBASE[kRegClipTop] = tileTop;
    clipRight--;
    clipBottom--;
    int a = tileLeft + kTileSize - 1;
    if (clipRight < a) a = clipRight;
    HWBASE[kRegClipRight] = a;
    a = tileTop + kTileSize - 1;
    if (clipBottom < a) a = clipBottom;
    HWBASE[kRegClipBot] = a;
    HWBASE[kRegClipEnable] = 1;
}


void librender::fillTriangle(TriangleFiller &filler,
    int tileLeft, int tileTop,
    int x1, int y1, int x2, int y2, int x3, int y3,
    int clipRight, int clipBottom)
{
    int thread = __builtin_nyuzi_read_control_reg(0);
    volatile unsigned int* const HWBASE = (volatile unsigned int*)(0xffff0100 + (thread<<6));
#if 0
    HWBASE[kRegClipLeft] = tileLeft;
    HWBASE[kRegClipTop] = tileTop;
    //HWBASE[kRegClipRight] = clipRight;
    //HWBASE[kRegClipBot] = clipBottom;
    clipRight--;
    clipBottom--;
    int a = tileLeft + kTileSize - 1;
    if (clipRight < a) a = clipRight;
    HWBASE[kRegClipRight] = a;
    a = tileTop + kTileSize - 1;
    if (clipBottom < a) a = clipBottom;
    HWBASE[kRegClipBot] = a;
    HWBASE[kRegClipEnable] = 1;
#endif

    HWBASE[kRegX1] = x1 << 16;
    HWBASE[kRegY1] = y1 << 16;
    HWBASE[kRegX2] = x2 << 16;
    HWBASE[kRegY2] = y2 << 16;
    HWBASE[kRegX3] = x3 << 16;
    HWBASE[kRegY3] = y3 << 16;

    HWBASE[kRegEnable] = 1;
    int s;
    while ((s=HWBASE[kRegStatus]) & 2) {
        if (s&1) {
            int x, y, m;
            x = HWBASE[kRegPatchX];
            y = HWBASE[kRegPatchY];
            m = HWBASE[kRegMask];
            HWBASE[kRegAction] = 1;
			filler.fillMasked(x, y, m);
            //total_fills++;
        }
        //total_loops++;
    }
    HWBASE[kRegEnable] = 0;
}
#endif


