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

//
// Various runtime functions, which are just included in-line for simplicity
//

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
unsigned int allocNext = 0x10000;

extern "C"  {
	void __cxa_atexit(void (*f)(void *), void *objptr, void *dso);
	void __cxa_pure_virtual();
	void memcpy(void *output, const void *input, unsigned int len);
	void memset(void *output, int value, unsigned int len);
	void *calloc(unsigned int size, int count);
	int strcmp(const char *str1, const char *str2);
	char* strcpy(char *dest, const char *src);
	unsigned long strlen(const char *str);
	unsigned int __udivsi3(unsigned int, unsigned int);
	int __divsi3(int, int);
	unsigned int __umodsi3(unsigned int, unsigned int);
	int __modsi3(int, int);
}

namespace std {
	class bad_alloc {
	};
};

void *operator new(unsigned int size) throw (std::bad_alloc)
{
	void *ptr = (void*) allocNext;
	allocNext += size;
	return ptr;
}

void operator delete(void *ptr) throw()
{
}

void __cxa_atexit(void (*f)(void *), void *objptr, void *dso)
{
}

void __cxa_pure_virtual()
{
}

void memset(void *output, int value, unsigned int len)
{
	for (int i = 0; i < len; i++)
		((char *)output)[i] = (char)value;
}

void memcpy(void *output, const void *input, unsigned int len)
{
	unsigned int i;

	for (i = 0; i < len; i++)
		((char*)output)[i] = ((char*)input)[i];
}


void *calloc(unsigned int size, int count)
{
	int totalSize = size * count;

	void *ptr = (void*) allocNext;
	allocNext += totalSize;
	memset(ptr, 0, totalSize);
	
	return ptr;
}

int strcmp(const char *str1, const char *str2)
{
	while (*str1) {
		if (*str2 == 0)
			return -1;

		if (*str1 != *str2)
			return *str1 - *str2;

		str1++;
		str2++;
	}

	if (*str2)
		return 1;

	return 0;
}

unsigned long strlen(const char *str)
{
	long len = 0;
	while (*str++)
		len++;

	return len;
}

char* strcpy(char *dest, const char *src)
{
	char *d = dest;
	while (*src)
		*d++ = *src++;

	*d = 0;
	return dest;
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
