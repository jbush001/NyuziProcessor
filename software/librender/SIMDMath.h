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

//
// Arithmetic on vector register values, and a few scalar straglers that
// I couldn't find anywhere else to put.
//

namespace librender
{

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

inline vecf16_t splatf(float f)
{
	return __builtin_nyuzi_makevectorf(f);
}

inline veci16_t splati(unsigned int i)
{
	return __builtin_nyuzi_makevectori(i);
}

template<int MAX>
inline veci16_t saturateiv(veci16_t in)
{
	return __builtin_nyuzi_vector_mixi(__builtin_nyuzi_mask_cmpi_ugt(in, splati(MAX)), splati(MAX), in);
}

inline vecf16_t minfv(vecf16_t a, vecf16_t b)
{
	return __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_lt(a, b), a, b);
}

inline vecf16_t maxfv(vecf16_t a, vecf16_t b)
{
	return __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_gt(a, b), a, b);
}

// Ensure all values in this vector are between 0.0 and 1.0
inline vecf16_t clampfv(vecf16_t in)
{
	return maxfv(minfv(in, splatf(1.0f)), splatf(0.0f));
}

inline vecf16_t floorfv(vecf16_t in)
{
	return __builtin_convertvector(__builtin_convertvector(in, veci16_t), vecf16_t);
}

// Return fractional part of value
inline vecf16_t fracfv(vecf16_t in)
{
	return in - floorfv(in);
}

inline vecf16_t absfv(vecf16_t in)
{
	// Note that the cast will not perform a conversion.
	return veci16_t(in) & splati(0x7fffffff);
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
