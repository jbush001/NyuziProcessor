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


#ifndef __TYPES_H
#define __TYPES_H

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));
typedef unsigned int vecu16 __attribute__((__vector_size__(16 * sizeof(int))));
typedef float vecf16 __attribute__((__vector_size__(16 * sizeof(float))));

// Splat macros convert a scalar value into a vector containing the same
// value in every lane.
#define splati(x) __builtin_vp_makevectori(x)
#define splatf(x) __builtin_vp_makevectorf(x)

//
// Ensure all values in this vector are between 0.0 and 1.0
//
inline vecf16 clampvf(vecf16 in)
{
	const vecf16 zero = splatf(0.0f);
	const vecf16 one = splatf(1.0f);
	vecf16 a = __builtin_vp_vector_mixf(__builtin_vp_mask_cmpf_lt(in, zero), zero, in);
	return __builtin_vp_vector_mixf(__builtin_vp_mask_cmpf_gt(a, one), one, a);
}

#endif
