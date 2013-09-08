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

#ifndef __INTERPOLATOR_H
#define __INTERPOLATOR_H

#include "vectypes.h"

class LinearInterpolator 
{
public:
	LinearInterpolator();
	void init(float x0, float y0, float c0, float x1, 
		float y1, float c1, float x2, float y2, float c2);
		
	inline vecf16 getValueAt(vecf16 x, vecf16 y) const
	{
		return x * __builtin_vp_makevectorf(fGx) + y * __builtin_vp_makevectorf(fGy)
			+ __builtin_vp_makevectorf(fC00);
	}

private:
	float fGx;	// dC/dX
	float fGy;	// dC/dY
	float fC00;	// Value of C at 0, 0
};


#endif
