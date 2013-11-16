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

#ifndef __TYPES_H
#define __TYPES_H

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));
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
	vecf16 a = __builtin_vp_blendf(__builtin_vp_mask_cmpf_lt(in, zero), zero, in);
	return __builtin_vp_blendf(__builtin_vp_mask_cmpf_gt(a, one), one, a);
}

#endif
