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


#ifndef __INTERPOLATOR_H
#define __INTERPOLATOR_H

#include <libc.h>
#include "RenderUtils.h"

namespace render
{

//
// 2D linear interpolator. Given the value of a parameter at 3 points in a plane, 
// determine the value at any other arbitrary point.
//
class LinearInterpolator 
{
public:
	LinearInterpolator();
	void init(float x0, float y0, float c0, float x1, 
		float y1, float c1, float x2, float y2, float c2);
	
	// Return values of this parameter at 16 locations given by the vectors
	// x and y.
	inline vecf16 getValuesAt(vecf16 x, vecf16 y) const
	{
		return x * splatf(fGx) + y * splatf(fGy) + splatf(fC00);
	}

private:
	float fGx;	// @C/@X
	float fGy;	// @C/@Y
	float fC00;	// Value of C at 0, 0
};

}

#endif
