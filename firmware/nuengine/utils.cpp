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

void memset(void *dest, int value, unsigned int length)
{
	for (unsigned int i = 0; i < length; i++)
		((char*) dest)[i] = value;
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

// 
// Hardware does not support integer division/modulus.
//
void udiv(unsigned int dividend, unsigned int divisor, unsigned int &outQuotient, 
	unsigned int &outRemainder)
{
	if (dividend < divisor)
	{
		outQuotient = 0;
		outRemainder = dividend;
		return;
	}

	int dividendHighBit = __builtin_clz(dividend);
	int divisorHighBit = __builtin_clz(divisor);
	int quotientBits = divisorHighBit - dividendHighBit;

	divisor <<= quotientBits;
	outQuotient = 0;
	do
	{
		outQuotient <<= 1;
		if (dividend >= divisor)
		{
			dividend -= divisor;
			outQuotient |= 1;
		}
		
		divisor >>= 1;
	}
	while (--quotientBits >= 0);

	outRemainder = dividend;
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
