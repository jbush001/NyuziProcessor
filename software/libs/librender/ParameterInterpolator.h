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


#pragma once 

#include <stdint.h>
#include "LinearInterpolator.h"

namespace librender
{

const int kMaxParams = 16;

//
// Perform perspective correct interpolation of parameters across a triangle.
// The triangle parameters are set up in world coordinate space, but the interpolant
// values will be requested in screen space. This maps those values properly.
// The basic approach is described in the paper "Perspective-Correct Interpolation" 
// by Kok-Lim Low.
//
// "the attribute value at point c in the image plane can be correctly derived by 
// just linearly interpolating between I1/Z1 and I2/Z2, and then divide the 
// interpolated result by 1/Zt, which itself can be derived by linear interpolation"
//
//

class ParameterInterpolator
{
public:
	// Coordinates are in screen space (-1.0 -> 1.0)
	void setUpTriangle(float x0, float y0, float z0, 
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

	// c1, c2, and c2 represent the value of the parameter at the three
	// triangle points specified in setUpTriangle.
	void setUpParam(float c0, float c1, float c2)
	{
		fParamOverZInterpolator[fNumParams++].init(fX0, fY0, c0 / fZ0,
			fX1, fY1, c1 / fZ1,
			fX2, fY2, c2 / fZ2);
	}

	// Compute 16 parameter values
	// Note that this computes the value for *all* parameters associated with this
	// triangle and stores them in the params array. The number of output params
	// is determined by the maximum index passed to setUpParam.
	void computeParams(vecf16_t x, vecf16_t y, vecf16_t outParams[],
		vecf16_t &outZValues) const
	{
		// Perform perspective correct interpolation of parameters
		vecf16_t zValues = splatf(1.0f) / fOneOverZInterpolator.getValuesAt(x, y);
		for (int i = 0; i < fNumParams; i++)
			outParams[i] = fParamOverZInterpolator[i].getValuesAt(x, y) * zValues;

		outZValues = zValues;
	}

	
private:
	LinearInterpolator fOneOverZInterpolator;
	LinearInterpolator fParamOverZInterpolator[kMaxParams];
	int fNumParams = 0;
	float fX0;
	float fY0;
	float fZ0;
	float fX1;
	float fY1;
	float fZ1;
	float fX2;
	float fY2;
	float fZ2;
};

}
