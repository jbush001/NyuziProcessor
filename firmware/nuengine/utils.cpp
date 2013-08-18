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

void operator delete(void *ptr) throw()
{
}

void *__dso_handle;

extern "C" void __cxa_atexit(void (*f)(void *), void *objptr, void *dso)
{
}

extern "C" void __cxa_pure_virtual()
{
}
