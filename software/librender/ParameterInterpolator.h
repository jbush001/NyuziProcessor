// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


#ifndef __PARAMETER_INTERPOLATOR_H
#define __PARAMETER_INTERPOLATOR_H

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
	void setUpTriangle(float x1, float y1, float z1, 
		float x2, float y2, float z2,
		float x3, float y3, float z3);

	// c1, c2, and c2 represent the value of the parameter at the three
	// triangle points specified in setUpTriangle.
	void setUpParam(int paramIndex, float c1, float c2, float c3);

	// Compute 16 parameter values
	// Note that this computes the value for *all* parameters associated with this
	// triangle and stores them in the params array. The number of output params
	// is determined by the maximum index passed to setUpParam.
	void computeParams(vecf16_t x, vecf16_t y, vecf16_t params[], vecf16_t &outZValues) const;
	
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

#endif
