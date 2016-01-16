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

#include <stdbool.h>
#include <stdint.h>

#define MIN(a, b) ((a) < (b) ? (a) : (b))

#define INT8_PTR(memory, address) ((int8_t*)(memory) + (address))
#define UINT8_PTR(memory, address) ((uint8_t*)(memory) + (address))
#define INT16_PTR(memory, address) ((int16_t*)(memory) + (address) / 2)
#define UINT16_PTR(memory, address) ((uint16_t*)(memory) + (address) / 2)
#define UINT32_PTR(memory, address) ((uint32_t*)(memory) + (address) / 4)

static inline uint32_t endianSwap32(uint32_t value)
{
    return ((value & 0x000000ff) << 24)
           | ((value & 0x0000ff00) << 8)
           | ((value & 0x00ff0000) >> 8)
           | ((value & 0xff000000) >> 24);
}

static inline uint32_t extractUnsignedBits(uint32_t word, uint32_t lowBitOffset, uint32_t size)
{
    return (word >> lowBitOffset) & ((1u << size) - 1);
}

static inline uint32_t extractSignedBits(uint32_t word, uint32_t lowBitOffset, uint32_t size)
{
    uint32_t mask = (1u << size) - 1;
    uint32_t value = (word >> lowBitOffset) & mask;
    if (value & (1u << (size - 1)))
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
