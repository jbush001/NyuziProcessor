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

#ifndef __PARAMETER_INTERPOLATOR_H
#define __PARAMETER_INTERPOLATOR_H

#include "LinearInterpolator.h"
#include "vectypes.h"

namespace render
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

class ParameterInterpolator
{
public:
	ParameterInterpolator(int width, int height);

	// Coordinates are in screen space (-1.0 -> 1.0)
	void setUpTriangle(float x1, float y1, float z1, 
		float x2, float y2, float z2,
		float x3, float y3, float z3);

	// c1, c2, and c2 represent the value of the parameter at the three
	// triangle points specified in setUpTriangle.
	void setUpParam(int paramIndex, float c1, float c2, float c3);

	// Compute 16 parameter values in a 4x4 pixel grid with the upper left pixel
	// at left, top.  These coordinates are in screen space (-1.0 - 1.0).
	// Note that this computes the value for *all* parameters associated with this
	// triangle and stores them in the params array. The number of output params
	// is determined by the maximum index passed to setUpParam.
	void computeParams(float left, float top, vecf16 params[], vecf16 &outZValues);
	
private:
	LinearInterpolator fOneOverZInterpolator;
	LinearInterpolator fParamOverZInterpolator[kMaxParams];
	int fNumParams;
	float fX0;
	float fY0;
	float fZ0;
	float fX1;
	float fY1;
	float fZ1;
	float fX2;
	float fY2;
	float fZ2;
	vecf16 fXStep;
	vecf16 fYStep;
};

}

#endif
