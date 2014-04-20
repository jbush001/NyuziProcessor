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

//
// Standard library functions, math, etc.
//

#include "vectypes.h"

#define M_PI 3.14159265359f

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

extern "C" {
	void memcpy(void *dest, const void *src, unsigned int length);
	void memset(void *dest, int value, unsigned int length);
	float fmod(float val1, float val2);
	float sin(float angle);
	float cos(float angle);
	float sqrt(float value);
};

void *allocMem(unsigned int size);

// Flush a data cache line from both L1 and L2.
inline void dflush(unsigned int address)
{
	asm("dflush %0" : : "s" (address));
}

// Stop all threads and halt simulation.
inline void __halt() __attribute__((noreturn));

inline void __halt()
{
	asm("setcr s0, 31");
	while (true)
		;
}
	
#endif
