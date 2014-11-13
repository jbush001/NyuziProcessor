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

#include <stdint.h>

namespace render
{

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

inline vecf16_t splatf(float f)
{
	return __builtin_nyuzi_makevectorf(f);
}

inline veci16_t splati(unsigned int i)
{
	return __builtin_nyuzi_makevectori(i);
}

//
// Ensure all values in this vector are between 0.0 and 1.0
//
inline vecf16_t clampvf(vecf16_t in)
{
	const vecf16_t zero = splatf(0.0f);
	const vecf16_t one = splatf(1.0f);
	vecf16_t a = __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_lt(in, zero), zero, in);
	return __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_gt(a, one), one, a);
}

}
	
#endif
