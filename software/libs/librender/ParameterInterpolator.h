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
		fX0 = x0;
		fY0 = y0;
		fZ0 = z0;
		fZ1 = z1;
		fZ2 = z2;
		
		// We can express the deltas of any parameter as the 
		// following system of equations, where gX and gY 
		// represent the change of the coefficient for changes
		// in X and Y. and c_n represents the coefficient at each
		// point:
		// | a b | | gX | = | c1 - c0 |
		// | c d | | gY |   | c2 - c0 |
		float a = x1 - x0;
		float b = y1 - y0;
		float c = x2 - x0;
		float d = y2 - y0;
		
		// Invert the matrix so we can find the gradients given
		// the coefficients.
		float oneOverDeterminant = 1.0 / (a * d - b * c);
		fA00 = d * oneOverDeterminant;
		fA10 = -c * oneOverDeterminant;
		fA01 = -b * oneOverDeterminant;
		fA11 = a * oneOverDeterminant;

		// Compute one over Z
		fOneOverZInterpolator.init(fA00, fA01, fA10, fA11, fX0, fY0, 1.0f / z0, 
			1.0f / z1, 1.0f / z2);
		fNumParams = 0;
	}

	// c1, c2, and c2 represent the value of the parameter at the three
	// triangle points specified in setUpTriangle.
	void setUpParam(float c0, float c1, float c2)
	{
		fParamOverZInterpolator[fNumParams++].init(fA00, fA01, fA10, fA11, 
			fX0, fY0, c0 / fZ0, c1 / fZ1, c2 / fZ2);
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
	float fZ0;
	float fZ1;
	float fZ2;
	float fX0;
	float fY0;
	
	// Inverse gradient matrix
	float fA00;
	float fA01;
	float fA10;
	float fA11;
};

}
