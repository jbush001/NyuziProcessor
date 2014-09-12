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


#ifndef __UTILS_H
#define __UTILS_H

#include <libc.h>

//
// Standard library functions, math, etc.
//

template <typename T>
inline T min(const T &a, const T &b)
{
	if (a < b)
		return a;
	else
		return b;
}

template <typename T>
inline T max(const T &a, const T &b)
{
	if (a > b)
		return a;
	else
		return b;
}

// Flush a data cache line from both L1 and L2.
inline void dflush(unsigned int address)
{
	asm("dflush %0" : : "s" (address));
}

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
