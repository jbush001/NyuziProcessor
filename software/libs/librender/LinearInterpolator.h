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

#include "SIMDMath.h"

namespace librender
{

//
// 2D linear interpolator.
//

class LinearInterpolator 
{
public:
	// The values a, b, c, d are a matrix that transform the coefficients into
	// the standard basis.
	// | a b |
	// | c d |
	void init(float a, float b, float c, float d, float x0, float y0, 
		float c0, float c1, float c2)
	{
		// Multiply by the matrix to find gradients
		float e = c1 - c0;
		float f = c2 - c0;
		fXGradient = a * e + b * f;
		fYGradient = c * e + d * f;

		// Compute c at 0, 0
		fC00 = c0 + -x0 * fXGradient + -y0 * fYGradient;	
	}
	
	// Return values of this parameter at 16 locations given by the vectors
	// x and y.
	inline vecf16_t getValuesAt(vecf16_t x, vecf16_t y) const
	{
		return x * splatf(fXGradient) + y * splatf(fYGradient) + splatf(fC00);
	}

private:
	float fXGradient;
	float fYGradient;
	float fC00;	// Value of C at 0, 0
};

}
