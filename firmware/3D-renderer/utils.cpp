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


#include "Debug.h"
#include "utils.h"

extern "C"  {
	unsigned int __udivsi3(unsigned int, unsigned int);
	int __divsi3(int, int);
	unsigned int __umodsi3(unsigned int, unsigned int);
	int __modsi3(int, int);
}

void *__dso_handle;
static volatile unsigned int gNextAlloc = 0x300000;	

void memcpy(void *dest, const void *src, unsigned int length)
{
	for (unsigned int i = 0; i < length; i++)
		((char*) dest)[i] = ((const char *) src)[i];
}

void memset(void *_dest, int value, unsigned int length)
{
	char *dest = (char*) _dest;
	value &= 0xff;

	if ((((unsigned int) dest) & 63) == 0)
	{
		// Write 64 bytes at a time.
		veci16 reallyWideValue = splati(value | (value << 8) | (value << 16) 
			| (value << 24));
		while (length > 64)
		{
			*((veci16*) dest) = reallyWideValue;
			length -= 64;
			dest += 64;
		}
	}

	if ((((unsigned int) dest) & 3) == 0)
	{
		// Write 4 bytes at a time.
		unsigned wideVal = value | (value << 8) | (value << 16) | (value << 24);
		while (length > 4)
		{
			*((unsigned int*) dest) = wideVal;
			dest += 4;
			length -= 4;
		}		
	}

	// Write one byte at a time
	while (length > 0)
	{
		*dest++ = value;
		length--;
	}
}

void *allocMem(unsigned int size)
{
	return (void*) __sync_fetch_and_add(&gNextAlloc, (size + 63) & ~63);
}

void *operator new(unsigned int size)
{
	return allocMem(size);
}

void operator delete(void *) throw()
{
	// Unimplemented
}

extern "C" void __cxa_atexit(void (*)(void *), void *, void *)
{
}

extern "C" void __cxa_pure_virtual()
{
	Debug::debug << "pure virtual\n";
	__halt();
}

//
// We don't support integer division in hardware, so emulate those functions
// here.
//
unsigned int __udivsi3(unsigned int dividend, unsigned int divisor)
{
	if (dividend < divisor)
		return 0;

	int quotientBits = __builtin_clz(divisor) - __builtin_clz(dividend);

	divisor <<= quotientBits;
	unsigned int quotient = 0;
	do
	{
		quotient <<= 1;
		if (dividend >= divisor)
		{
			dividend -= divisor;
			quotient |= 1;
		}
		
		divisor >>= 1;
	}
	while (--quotientBits >= 0);

	return quotient;
}

int __divsi3(int value1, int value2)
{
	int sign1 = value1 >> 31;
	int sign2 = value2 >> 31;
	
	// Take absolute values
	unsigned int u_value1 = (value1 ^ sign1) - sign1;
	unsigned int u_value2 = (value2 ^ sign2) - sign2;

	// Compute result sign
	sign1 ^= sign2;

	// Perform division, then convert back to 2's complement
	return (__udivsi3(u_value1, u_value2) ^ sign1) - sign1;
}

unsigned int __umodsi3(unsigned int value1, unsigned int value2)
{
	return value1 - __udivsi3(value1, value2) * value2;
}

int __modsi3(int value1, int value2)
{
	return value1 - __divsi3(value1, value2) * value2;
}

//
// Math functions
//

float fmod(float val1, float val2)
{
	int whole = val1 / val2;
	return val1 - (whole * val2);
}

//
// Use taylor series to approximate sine
//   x**3/3! + x**5/5! - x**7/7! ...
//

const int kNumTerms = 7;

const float denominators[] = { 
	0.166666666666667f, 	// 1 / 3!
	0.008333333333333f,		// 1 / 5!
	0.000198412698413f,		// 1 / 7!
	0.000002755731922f,		// 1 / 9!
	2.50521084e-8f,			// 1 / 11!
	1.6059044e-10f,			// 1 / 13!
	7.6471637e-13f			// 1 / 15!
};

float sin(float angle)
{
	// More accurate if the angle is smaller. Constrain to 0-M_PI*2
	angle = fmod(angle, M_PI * 2.0f);

	float angleSquared = angle * angle;
	float numerator = angle;
	float result = angle;
	
	for (int i = 0; i < kNumTerms; i++)
	{
		numerator *= angleSquared;		
		float term = numerator * denominators[i];
		if (i & 1)
			result += term;
		else
			result -= term;
	}
	
	return result;
}

float cos(float angle)
{
	return sin(angle + M_PI * 0.5f);
}

float sqrt(float value)
{
	float guess = value;
	for (int iteration = 0; iteration < 10; iteration++)
		guess = ((value / guess) + guess) / 2.0f;

	return guess;
}
