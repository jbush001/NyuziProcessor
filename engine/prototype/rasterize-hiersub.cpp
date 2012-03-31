//
// Rasterize a triangle by hierarchial subdivision
//

#include <stdio.h>
#include <string.h>
#include "vec16.h"

#define FB_SIZE 64
#define S0 0
#define S1 (FB_SIZE / 4)
#define S2 (FB_SIZE * 2 / 4)
#define S3 (FB_SIZE * 3 / 4)

void setPixel(int x, int y, char c);
void fillRect(int left, int top, int size);
void fillMasked(int left, int top, int mask);
void printFb();

const int kXSteps[] = { S0, S1, S2, S3, S0, S1, S2, S3, S0, S1, S2, S3, S0, S1, S2, S3 };
const int kYSteps[] = { S0, S0, S0, S0, S1, S1, S1, S1, S2, S2, S2, S2, S3, S3, S3, S3 };
char framebuffer[FB_SIZE * FB_SIZE];

static int findHighestBit(int value)
{
	int index;
	
	for (index = 31; index >= 0; index--)
	{
		if (value & (1 << index))
			return index;
	}
	
	return -1;
}

void fillRects(int gridLeft, int gridTop, int subTileSize, int mask)
{
	int index;

	printf("fillRects(%d,%d,%d,0x%04x)\n", gridLeft, gridTop, subTileSize, mask);

	while ((index = findHighestBit(mask)) >= 0)
	{			
		mask &= ~(1 << index);
		int blockLeft = gridLeft + subTileSize * ((15 - index) & 3);
		int blockTop = gridTop + subTileSize * ((15 - index) >> 2);
		for (int y = 0; y < subTileSize; y++)
		{
			for (int x = 0; x < subTileSize; x++)
				framebuffer[(y + blockTop) * FB_SIZE + (x + blockLeft)]  = 'X';
		}
	}
}

void fillMasked(int left, int top, int mask)
{
	int x;
	int y;
	int index;

	printf("fillMasked(%d,%d,%d)\n", left, top, mask);
	for (index = 15; index >= 0; index--)
	{
		x = left + ((15 - index) & 3);
		y = top + ((15 - index) >> 2);
		
		if (mask & (1 << index))
			framebuffer[y * FB_SIZE + x] = 'X';
	}
}

void printFb()
{
	int x, y;
	int index = 0;
	
	for (y = 0; y < FB_SIZE; y++)
	{
		for (x = 0; x < FB_SIZE; x++)
			printf("%c", framebuffer[index++]);
		
		printf("\n");
	}	

}

static void setupEdge(int x1, int y1, int x2, int y2, int &outAcceptEdgeValue, 
	int &outRejectEdgeValue, Vec16<int> &outAcceptStepMatrix, Vec16<int> &outRejectStepMatrix)
{
	Vec16<int> xAcceptStepValues;
	Vec16<int> yAcceptStepValues;
	Vec16<int> xRejectStepValues;
	Vec16<int> yRejectStepValues;
	int xStep;
	int yStep;
	int trivialAcceptX;
	int trivialAcceptY;
	int trivialRejectX;
	int trivialRejectY;

	xAcceptStepValues.load(kXSteps);
	xRejectStepValues.load(kXSteps);
	yAcceptStepValues.load(kYSteps);
	yRejectStepValues.load(kYSteps);

	if (y2 > y1)
	{
		trivialAcceptX = FB_SIZE - 1;
		xAcceptStepValues = xAcceptStepValues - S3;
	}
	else
	{
		trivialAcceptX = 0;
		xRejectStepValues = xRejectStepValues - S3;
	}

	if (x2 > x1)
	{
		trivialAcceptY = 0;
		yRejectStepValues = yRejectStepValues - S3;
	}
	else
	{
		trivialAcceptY = FB_SIZE - 1;
		yAcceptStepValues = yAcceptStepValues - S3;
	}

	trivialRejectX = (FB_SIZE - 1) - trivialAcceptX;
	trivialRejectY = (FB_SIZE - 1) - trivialAcceptY;

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

static void subdivideTile( 
	int acceptCornerValue1, 
	int acceptCornerValue2, 
	int acceptCornerValue3,
	int rejectCornerValue1, 
	int rejectCornerValue2,
	int rejectCornerValue3,
	Vec16<int> acceptStep1, 
	Vec16<int> acceptStep2, 
	Vec16<int> acceptStep3, 
	Vec16<int> rejectStep1, 
	Vec16<int> rejectStep2, 
	Vec16<int> rejectStep3, 
	int tileSize,
	int left,
	int top)
{
	Vec16<int> acceptEdgeValue1;
	Vec16<int> acceptEdgeValue2;
	Vec16<int> acceptEdgeValue3;
	Vec16<int> rejectEdgeValue1;
	Vec16<int> rejectEdgeValue2;
	Vec16<int> rejectEdgeValue3;
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
		fillMasked(left, top, trivialAcceptMask);
		return;
	}

	// Reduce tile size for sub blocks
	tileSize = tileSize / 4;

	// Process all trivially accepted blocks
	if (trivialAcceptMask != 0)
		fillRects(left, top, tileSize, trivialAcceptMask);
	
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
		while ((index = findHighestBit(recurseMask)) >= 0)
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

void rasterizeTriangle(int x1, int y1, int x2, int y2, int x3, int y3)
{
	int acceptValue1;
	int rejectValue1;
	Vec16<int> acceptStepMatrix1;
	Vec16<int> rejectStepMatrix1;
	int acceptValue2;
	int rejectValue2;
	Vec16<int> acceptStepMatrix2;
	Vec16<int> rejectStepMatrix2;
	int acceptValue3;
	int rejectValue3;
	Vec16<int> acceptStepMatrix3;
	Vec16<int> rejectStepMatrix3;

	setupEdge(x1, y1, x2, y2, acceptValue1, rejectValue1, acceptStepMatrix1, rejectStepMatrix1);
	setupEdge(x2, y2, x3, y3, acceptValue2, rejectValue2, acceptStepMatrix2, rejectStepMatrix2);
	setupEdge(x3, y3, x1, y1, acceptValue3, rejectValue3, acceptStepMatrix3, rejectStepMatrix3);

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
		0, 0);
}

int main(int argc, const char *argv[])
{
	memset(framebuffer, ' ', FB_SIZE * FB_SIZE);
	rasterizeTriangle(32, 12, 52, 48, 3, 57);
	printFb();

	return 0;
}
