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
#include "ParameterInterpolator.h"

ParameterInterpolator::ParameterInterpolator(int width, int height)
	:	fNumParams(0)
{
	for (int x = 0; x < 4; x++)
	{
		for (int y = 0; y < 4; y++)
		{
			fXStep[y * 4 + x] = float(x) / width;
			fYStep[y * 4 + x] = float(y) / height;
		}
	}
}

void ParameterInterpolator::setUpTriangle(
	float x0, float y0, float z0, 
	float x1, float y1, float z1,
	float x2, float y2, float z2)
{
	fOneOverZInterpolator.init(x0, y0, 1.0f / z0, x1, y1, 1.0f / z1, x2, y2, 1.0f / z2);
	fNumParams = 0;

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

void ParameterInterpolator::setUpParam(int paramIndex, float c0, float c1, float c2)
{
	fParamOverZInterpolator[paramIndex].init(fX0, fY0, c0 / fZ0,
		fX1, fY1, c1 / fZ1,
		fX2, fY2, c2 / fZ2);
	if (paramIndex + 1 > fNumParams)
		fNumParams = paramIndex + 1;
}

void ParameterInterpolator::computeParams(float left, float top, vecf16 params[],
	vecf16 &outZValues)
{
	vecf16 x = fXStep + __builtin_vp_makevectorf(left);
	vecf16 y = fYStep + __builtin_vp_makevectorf(top);

	// Perform perspective correct interpolation of parameters
	vecf16 zValues = __builtin_vp_makevectorf(1.0f) 
		/ fOneOverZInterpolator.getValueAt(x, y);
	for (int i = 0; i < fNumParams; i++)
		params[i] = fParamOverZInterpolator[i].getValueAt(x, y) * zValues;

	outZValues = zValues;
}
