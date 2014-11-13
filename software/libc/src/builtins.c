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

unsigned long long int __muldi3(unsigned long long int a, unsigned long long int b)
{
	unsigned int a_low = a;
	unsigned int b_low = b;
	unsigned int a_high = a >> 32;
	unsigned int b_high = b >> 32;

	unsigned long long int result = a_low * b_low;
	result += (unsigned long long int)(a_high * b_low + a_low * b_high) << 32;
	return result;
}
