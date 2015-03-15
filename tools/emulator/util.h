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


#ifndef __UTIL_H
#define __UTIL_H

#include <stdint.h>

#define MIN(a, b) ((a) < (b) ? (a) : (b))

int parseHexVector(const char *str, uint32_t vectorValues[16], int endianSwap);

static inline uint32_t endianSwap32(uint32_t value)
{
	return ((value & 0x000000ff) << 24)
		| ((value & 0x0000ff00) << 8)
		| ((value & 0x00ff0000) >> 8)
		| ((value & 0xff000000) >> 24);
}

static inline int extractUnsignedBits(uint32_t word, int lowBitOffset, int size)
{
	return (word >> lowBitOffset) & ((1 << size) - 1);
}

static inline int extractSignedBits(uint32_t word, int lowBitOffset, int size)
{
	uint32_t mask = (1 << size) - 1;
	int value = (word >> lowBitOffset) & mask;
	if (value & (1 << (size - 1)))
		value |= ~mask;	// Sign extend

	return value;
}

// Treat integer bitpattern as float without converting
// This is legal in C99
static inline float valueAsFloat(uint32_t value)
{
	union 
	{
		float f;
		uint32_t i;
	} u = { .i = value };

	return u.f;
}

// Treat floating point bitpattern as int without converting
static inline uint32_t valueAsInt(float value)
{
	union 
	{
		float f;
		uint32_t i;
	} u = { .f = value };

	// The contents of the significand of a NaN result is not fully determined
	// in the spec.  For consistency in cosimulation, convert to a common form 
	// when it is detected.
	if (((u.i >> 23) & 0xff) == 0xff && (u.i & 0x7fffff) != 0)
		return 0x7fffffff;
	
	return u.i;
}

#endif
