#include "PixelShader.h"

void PixelShader::shadePixels(const vec16<float> inParams[16], vec16<float> outParams[16])
{
	outParams[0] = inParams[0];	// Red
	outParams[1] = inParams[1];	// Blue
	outParams[2] = inParams[2];	// Green
}
