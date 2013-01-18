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

#include "PixelShaderState.h"

PixelShaderState::PixelShaderState(OutputBuffer *outputBuffer)
	:	fNumParams(0),
		fShader(NULL),
		fOutputBuffer(outputBuffer)
{
	float xvals[16];
	float yvals[16];
	
	float xStep = 1.0 / outputBuffer->getWidth();
	float yStep = 1.0 / outputBuffer->getHeight();

	for (int x = 0; x < 4; x++)
	{
		for (int y = 0; y < 4; y++)
		{
			xvals[y * 4 + x] = xStep * x;
			yvals[y * 4 + x] = yStep * y;
		}
	}
	
	fXStep.load(xvals);
	fYStep.load(yvals);
}

void PixelShaderState::setUpTriangle(
	float x0, float y0, float z0, 
	float x1, float y1, float z1,
	float x2, float y2, float z2,
	PixelShader *shader)
{
	fZInterpolator.init(x0, y0, 1.0 / z0, x1, y1, 1.0 / z1, x2, y2, 1.0 / z2);
	fNumParams = 0;
	fShader = shader;

	fX0 = x0;
	fY0 = y0;
	fZ0 = z0;
	fX1 = x1;
	fY1 = y1;
	fZ1 = z1;
	fX2 = x2;
	fY2 = y2;
	fZ2 = z2;
}

void PixelShaderState::setUpParam(int paramIndex, float c0, float c1, float c2)
{
	fParamInterpolators[paramIndex].init(fX0, fY0, c0 / fZ0,
		fX1, fY1, c1 / fZ1,
		fX2, fY2, c2 / fZ2);
	if (paramIndex + 1 > fNumParams)
		fNumParams = paramIndex + 1;
}

void PixelShaderState::fillMasked(int left, int top, unsigned short mask)
{
	vec16<float> x = fXStep + ((float) left / fOutputBuffer->getWidth());
	vec16<float> y = fYStep + ((float) top / fOutputBuffer->getHeight());

	// Perform perspective correct interpolation of parameters
	vec16<float> inParams[kMaxParams];
	vec16<float> zMultiplier = fZInterpolator.getValueAt(x, y).reciprocal();
	for (int i = 0; i < fNumParams; i++)
		inParams[i] = fParamInterpolators[i].getValueAt(x, y) * zMultiplier;

	vec16<float> outParams[kMaxParams];
	
	fShader->shadePixels(inParams, outParams);

	// Assume outParams 0, 1, 2, 3 are r, g, b, and a of an output pixel
	fOutputBuffer->fillMasked(left, top, mask, outParams[0], outParams[1], outParams[2]);
}
	
