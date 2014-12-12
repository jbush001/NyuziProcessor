// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 

#ifndef __UTIL_H
#define __UTIL_H

#define MIN(a, b) ((a) < (b) ? (a) : (b))

int parseHexVector(const char *str, unsigned int vectorValues[16], int endianSwap);

static inline int endianSwap32(unsigned int value)
{
	return ((value & 0x000000ff) << 24)
		| ((value & 0x0000ff00) << 8)
		| ((value & 0x00ff0000) >> 8)
		| ((value & 0xff000000) >> 24);
}

static inline int extractSignedBits(unsigned int word, int lowBitOffset, int size)
{
	return (word >> lowBitOffset) & ((1 << size) - 1);
}

static inline int extractUnsignedBits(unsigned int word, int lowBitOffset, int size)
{
	unsigned int mask = (1 << size) - 1;
	int value = (word >> lowBitOffset) & mask;
	if (value & (1 << (size - 1)))
		value |= ~mask;	// Sign extend

	return value;
}

static inline float valueAsFloat(unsigned int value)
{
	return *((float*) &value);
}

static inline unsigned int valueAsInt(float value)
{
	unsigned int ival = *((unsigned int*) &value);

	// The contents of the significand of a NaN result is not fully determined
	// in the spec.  For simplicity, convert to a common form when it is detected.
	if (((ival >> 23) & 0xff) == 0xff && (ival & 0x7fffff) != 0)
		return 0x7fffffff;
	
	return ival;
}

#endif
