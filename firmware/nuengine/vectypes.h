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

inline vecf16 blendf(unsigned int mask, vecf16 inA, vecf16 inB)
{
	vecf16 out;
	
	__asm__("move %0, %1\n"
		"move.mask %0, %3, %2" 
		: "=v" (out) 
		: "v" (inB), "v" (inA), "s" (mask));

	return out;
}

inline vecf16 clampvf(vecf16 in)
{
	vecf16 a = blendf(__builtin_vp_mask_cmpf_lt(in, splatf(0.0f)), splatf(0.0f), in);
	return blendf(__builtin_vp_mask_cmpf_gt(a, splatf(1.0f)), splatf(1.0f), a);
}

#endif
