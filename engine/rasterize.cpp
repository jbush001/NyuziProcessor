//
// Rasterize a triangle by hierarchial subdivision
//

#include <stdio.h>
#include <string.h>

#define FB_SIZE 64
#define S0 0
#define S1 (FB_SIZE / 4)
#define S2 (FB_SIZE * 2 / 4)
#define S3 (FB_SIZE * 3 / 4)


class Vec16
{
public:
	Vec16();
    Vec16 &operator=(const Vec16&);
    Vec16 operator*(int) const;
    Vec16 operator>>(int) const;
    Vec16 operator+(const Vec16&) const;
    Vec16 operator+(int) const;
    Vec16 operator-(const Vec16&) const;
    Vec16 operator-(int) const;
    int operator>=(int) const;
    int operator<=(int) const;
    void load(const int values[]);
    int operator[](int index) const;
    
private:
	int fValues[16];
};

void setPixel(int x, int y, char c);
void fillRect(int left, int top, int size);
void fillMasked(int left, int top, int mask);
void printFb();

const int kXSteps[] = { S3, S2, S1, S0, S3, S2, S1, S0, S3, S2, S1, S0, S3, S2, S1, S0 };
const int kYSteps[] = { S3, S3, S3, S3, S2, S2, S2, S2, S1, S1, S1, S1, S0, S0, S0, S0 };
char framebuffer[FB_SIZE * FB_SIZE];

void fillRect(int left, int top, int size)
{
	for (int y = 0; y < size; y++)
	{
		for (int x = 0; x < size; x++)
			framebuffer[(y + top) * FB_SIZE + (x + left)]  = 'X';
	}
}

void fillMasked(int left, int top, int mask)
{
	int x;
	int y;
	int index;

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

Vec16::Vec16()
{
    memset(fValues, 0, sizeof(fValues));
}

Vec16 &Vec16::operator=(const Vec16 &src)
{
	memcpy(fValues, src.fValues, sizeof(fValues));
}

Vec16 Vec16::operator*(int multiplier) const
{
    Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] * multiplier;

    return result;
}

Vec16 Vec16::operator>>(int shamt) const
{
    Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] >> shamt;

    return result;
}

Vec16 Vec16::operator+(const Vec16 &add) const
{
    Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] + add.fValues[i];

    return result;
}

Vec16 Vec16::operator+(int add) const
{
    Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] + add;

    return result;
}

Vec16 Vec16::operator-(const Vec16 &sub) const
{
    Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] - sub.fValues[i];

    return result;
}

Vec16 Vec16::operator-(int sub) const
{
    Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] - sub;

    return result;
}

int Vec16::operator>=(int cmpval) const
{
	int mask = 0;

	for (int i = 0; i < 16; i++)
		mask |= fValues[i] >= cmpval ? (1 << i) : 0;

    return mask;
}

int Vec16::operator<=(int cmpval) const
{
	int mask = 0;

	for (int i = 0; i < 16; i++)
		mask |= fValues[i] <= cmpval ? (1 << i) : 0;

    return mask;
}

void Vec16::load(const int values[])
{
	for (int i = 0; i < 16; i++)
		fValues[i] = values[i];
}

int Vec16::operator[](int index) const
{
	return fValues[index];
}

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

static void setupEdge(int x1, int y1, int x2, int y2, int &outAcceptEdgeValue, 
	int &outRejectEdgeValue, Vec16 &outAcceptStepMatrix, Vec16 &outRejectStepMatrix)
{
	Vec16 xAcceptStepValues;
	Vec16 yAcceptStepValues;
	Vec16 xRejectStepValues;
	Vec16 yRejectStepValues;
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

static void subdivideBlock( 
	int acceptCornerValue1, 
	int acceptCornerValue2, 
	int acceptCornerValue3,
	int rejectCornerValue1, 
	int rejectCornerValue2,
	int rejectCornerValue3,
	const Vec16 &acceptStep1, 
	const Vec16 &acceptStep2, 
	const Vec16 &acceptStep3, 
	const Vec16 &rejectStep1, 
	const Vec16 &rejectStep2, 
	const Vec16 &rejectStep3, 
	int tileSize,
	int left,
	int top)
{
	Vec16 acceptEdgeValue1;
	Vec16 acceptEdgeValue2;
	Vec16 acceptEdgeValue3;
	Vec16 rejectEdgeValue1;
	Vec16 rejectEdgeValue2;
	Vec16 rejectEdgeValue3;
	int trivialAcceptMask;
	int trivialRejectMask;
	Vec16 acceptSubStep1;
	Vec16 acceptSubStep2;
	Vec16 acceptSubStep3;
	Vec16 rejectSubStep1;
	Vec16 rejectSubStep2;
	Vec16 rejectSubStep3;
	int recurseMask;
	int index;
	int x, y;
	int subTileSize;
	
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
	
	// Compute reject masks
	rejectEdgeValue1 = rejectStep1 + rejectCornerValue1;
	trivialRejectMask = rejectEdgeValue1 >= 0;
	rejectEdgeValue2 = rejectStep2 + rejectCornerValue2;
	trivialRejectMask |= rejectEdgeValue2 >= 0;
	rejectEdgeValue3 = rejectStep3 + rejectCornerValue3;
	trivialRejectMask |= rejectEdgeValue3 >= 0;

	subTileSize = tileSize / 4;

	recurseMask = (~trivialAcceptMask & ~trivialRejectMask) & 0xffff;

	// Process all trivially accepted blocks
	while ((index = findHighestBit(trivialAcceptMask)) >= 0)
	{			
		trivialAcceptMask &= ~(1 << index);
		x = left + subTileSize * ((15 - index) & 3);
		y = top + subTileSize * ((15 - index) >> 2);
		fillRect(x, y, subTileSize);
	}

	if (recurseMask)
	{
		// Divide each step matrix by 4
		acceptSubStep1 = acceptStep1 >> 2;
		acceptSubStep2 = acceptStep2 >> 2;
		acceptSubStep3 = acceptStep3 >> 2;
		rejectSubStep1 = rejectStep1 >> 2;
		rejectSubStep2 = rejectStep2 >> 2;
		rejectSubStep3 = rejectStep3 >> 2;

		// Recurse into blocks that are neither trivially rejected or accepted.
		while ((index = findHighestBit(recurseMask)) >= 0)
		{
			recurseMask &= ~(1 << index);
			x = left + subTileSize * ((15 - index) & 3);
			y = top + subTileSize * ((15 - index) >> 2);

			// Partially overlapped parts need to be further subdivided
			subdivideBlock(
				acceptEdgeValue1[index],
				acceptEdgeValue2[index],
				acceptEdgeValue3[index],
				rejectEdgeValue1[index],
				rejectEdgeValue2[index],
				rejectEdgeValue3[index],
				acceptSubStep1,
				acceptSubStep2,
				acceptSubStep3,
				rejectSubStep1,
				rejectSubStep2,
				rejectSubStep3,
				subTileSize,
				x, y);			
		}
	}
}

void rasterizeTriangle(int x1, int y1, int x2, int y2, int x3, int y3)
{
	int acceptValue1;
	int rejectValue1;
	Vec16 acceptStepMatrix1;
	Vec16 rejectStepMatrix1;
	int acceptValue2;
	int rejectValue2;
	Vec16 acceptStepMatrix2;
	Vec16 rejectStepMatrix2;
	int acceptValue3;
	int rejectValue3;
	Vec16 acceptStepMatrix3;
	Vec16 rejectStepMatrix3;

	setupEdge(x1, y1, x2, y2, acceptValue1, rejectValue1, acceptStepMatrix1, rejectStepMatrix1);
	setupEdge(x2, y2, x3, y3, acceptValue2, rejectValue2, acceptStepMatrix2, rejectStepMatrix2);
	setupEdge(x3, y3, x1, y1, acceptValue3, rejectValue3, acceptStepMatrix3, rejectStepMatrix3);

	subdivideBlock(
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
