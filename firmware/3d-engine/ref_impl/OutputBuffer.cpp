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

#include "misc.h"
#include "OutputBuffer.h"

const int kBytesPerPixel = 4;	// Bytes per pixel

inline unsigned char convertPixel(float val)
{
	if (val <= 0.0)
		return 0;
	else if (val >= 1.0)
		return 0xff;
	else return (unsigned char) (256 * val);
}

OutputBuffer::OutputBuffer(int width, int height)
	:	fWidth(width),
		fHeight(height)
{
	fBufferData = (unsigned int*) malloc(kBytesPerPixel * width * height);
}

void OutputBuffer::fillMasked(int left, int top, unsigned short mask,
	const vec16<float> &red, const vec16<float> &blue, 
	const vec16<float> &green)
{
	int index;
	while ((index = clz(mask)) >= 0)
	{			
		mask &= ~(1 << index);
		int x = left + ((15 - index) & 3);
		int y = top + ((15 - index) >> 2);

		// Byte order is BGRA, but this will be endian swapped, so ARGB
		fBufferData[y * getWidth() + x] = 
			0xff000000
			| (convertPixel(red[index]) << 16)
			| (convertPixel(green[index]) << 8)
			| (convertPixel(blue[index]));
	}
}

int OutputBuffer::getWidth() const
{
	return fWidth;
}

int OutputBuffer::getHeight() const
{
	return fHeight;
}

void OutputBuffer::writeImage(const char *filename)
{
	FILE *file = fopen(filename, "wb");
	if (fwrite(fBufferData, 1, getWidth() * getHeight() * kBytesPerPixel, file) 
		< getWidth() * getHeight() * kBytesPerPixel)
	{
		printf("error writing file\n");
	}

	fclose(file);
}



