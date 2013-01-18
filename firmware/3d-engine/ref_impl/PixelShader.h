#ifndef __PIXEL_SHADER_H
#define __PIXEL_SHADER_H

#include "vec16.h"

class PixelShader
{
public:
	void shadePixels(const vec16<float> inParams[16], vec16<float> outParams[16]);
};

#endif
