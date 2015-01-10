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

#ifndef __RENDER_UTILS_H
#define __RENDER_UTILS_H

#include <stdint.h>

namespace librender
{

const int kCacheLineSize = 64;

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

// Ensure all values in this vector are between 0.0 and 1.0
inline vecf16_t clampfv(vecf16_t in)
{
	const vecf16_t zero = splatf(0.0f);
	const vecf16_t one = splatf(1.0f);
	vecf16_t a = __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_lt(in, zero), zero, in);
	return __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_gt(a, one), one, a);
}

template<int MAX>
inline veci16_t saturateiv(veci16_t in)
{
	return __builtin_nyuzi_vector_mixi(__builtin_nyuzi_mask_cmpi_ugt(in, splati(MAX)), splati(MAX), in);
}

// Return fractional part of value
inline vecf16_t fracv(vecf16_t in)
{
	return in - __builtin_nyuzi_vitof(__builtin_nyuzi_vftoi(in));
}

inline vecf16_t absfv(vecf16_t in)
{
	// Note that the cast will not perform a conversion.
	return veci16_t(in) & splati(0x7fffffff);
}

inline float fabs_f(float val)
{
	return val < 0.0 ? -val : val;
}

// Newton's method vector square root.
inline vecf16_t sqrtfv(vecf16_t value)
{
	vecf16_t guess = value;
	for (int iteration = 0; iteration < 6; iteration++)
		guess = ((value / guess) + guess) / splatf(2.0f);

	return guess;	
}

// "Quake" fast inverse square root
// Note that the integer casts here do not perform float/int conversions
// but just interpret the numbers directly as the opposite type.
inline vecf16_t isqrtfv(vecf16_t number)
{
	vecf16_t x2 = number * splatf(0.5f);
	vecf16_t y = vecf16_t(splati(0x5f3759df) - (veci16_t(x2) >> splati(1))); 
	y = y * (splatf(1.5f) - (x2 * y * y));
	return y;
}

}
	
#endif
