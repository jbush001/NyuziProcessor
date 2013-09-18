// 
// Copyright 2013 Jeff Bush
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

#include "Debug.h"
#include "utils.h"

namespace __cxxabiv1
{
	class __class_type_info
	{
	public:
		__class_type_info() {}
		virtual ~__class_type_info() {}
	};

	class __si_class_type_info
	{
	public:
		__si_class_type_info() {}
		virtual ~__si_class_type_info() {}
	};

	__class_type_info cti;
	__si_class_type_info sicti;
}

void *__dso_handle;

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

extern "C"  {
	unsigned int __udivsi3(unsigned int, unsigned int);
	int __divsi3(int, int);
	unsigned int __umodsi3(unsigned int, unsigned int);
	int __modsi3(int, int);
}

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
	// More accurate if the angle is smaller. Constrain to 0-M_PI
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
