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
// Arithmetic on vector register values, and a few scalar stragglers that
// I couldn't find anywhere else to put.
//

namespace librender
{

template <typename T>
inline const T& min(const T &a, const T &b)
{
    if (a < b)
        return a;
    else
        return b;
}

template <typename T>
inline const T& max(const T &a, const T &b)
{
    if (a > b)
        return a;
    else
        return b;
}

inline vecf16_t min(vecf16_t a, vecf16_t b)
{
    // This function follows the convention that, if a scalar is used, it is
    // the second parameter. Structuring the comparison as below uses two
    // instructions instead of three.
    return __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_gt(a, b), b, a);
}

inline vecf16_t max(vecf16_t a, vecf16_t b)
{
    return __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpf_lt(a, b), b, a);
}

inline vecu16_t min(vecu16_t a, vecu16_t b)
{
    return __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpi_ugt(a, b), b, a);
}

inline vecu16_t max(vecu16_t a, vecu16_t b)
{
    return __builtin_nyuzi_vector_mixf(__builtin_nyuzi_mask_cmpi_ult(a, b), b, a);
}

inline vecu16_t saturate(vecu16_t in, int max)
{
    return min(in, vecu16_t(max));
}

// Ensure all values in this vector are between low and high
inline vecf16_t clamp(vecf16_t in, float low, float high)
{
    return max(min(in, vecf16_t(high)), vecf16_t(low));
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
    // The cast does not perform a conversion.
    return vecf16_t(veci16_t(in) & 0x7fffffff);
}

// "Quake" fast inverse square root
// The integer casts here do not perform float/int conversions
// but just interpret the numbers directly as the opposite type.
inline vecf16_t isqrtfv(vecf16_t number)
{
    vecf16_t x2 = number * 0.5f;
    vecf16_t y = vecf16_t(0x5f3759df - (veci16_t(number) >> 1));
    y = y * (1.5f - (x2 * y * y));
    return y;
}

} // namespace librender
