#ifndef __OUTPUT_BUFFER_H
#define __OUTPUT_BUFFER_H

#include "vec16.h"

class OutputBuffer
{
public:
	OutputBuffer(int width, int height);
	void fillMasked(int left, int top, unsigned short mask,
		const vec16<float> &red, const vec16<float> &blue, 
		const vec16<float> &green);
	int getWidth() const;
	int getHeight() const;
	void writeImage(const char *filename);
	
private:
	unsigned int *fBufferData;
	int fWidth;
	int fHeight;
};

#endif
