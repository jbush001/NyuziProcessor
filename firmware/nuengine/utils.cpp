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

int countBits(unsigned int value)
{
	int bits = 0;
	while (value)
	{
		bits++;
		value &= (value - 1);
	}

	return bits;
}

void extractColorChannels(veci16 packedColors, vecf16 outColor[3])
{
	outColor[0] = __builtin_vp_vitof(packedColors & splati(255))
		/ splatf(255.0f);	// B
	outColor[1] = __builtin_vp_vitof((packedColors >> splati(8)) & splati(255)) 
		/ splatf(255.0f); // G
	outColor[2] = __builtin_vp_vitof((packedColors >> splati(16)) & splati(255)) 
		/ splatf(255.0f); // R
	outColor[3] = __builtin_vp_vitof((packedColors >> splati(24)) & splati(255)) 
		/ splatf(255.0f); // A
}

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

void operator delete(void *) throw()
{
}

void *__dso_handle;

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

	int dividendHighBit = __builtin_clz(dividend);
	int divisorHighBit = __builtin_clz(divisor);
	int quotientBits = divisorHighBit - dividendHighBit;

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

	// Perform division (will call __udivsi3), then convert sign back 
	return ((u_value1 / u_value2) ^ sign1) - sign1;
}

unsigned int __umodsi3(unsigned int value1, unsigned int value2)
{
	return value1 - __udivsi3(value1, value2) * value2;
}

int __modsi3(int value1, int value2)
{
	return value1 - __divsi3(value1, value2) * value2;
}


