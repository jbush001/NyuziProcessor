

void printChar(char c)
{
	*((volatile unsigned int*) 0xFFFF0004) = c;
}

int fib(int n)
{
	if (n < 2)
		return n;
	else 
		return fib(n - 1) + fib(n - 2);
}

void printHex(unsigned int value)
{
	for (int i = 0; i < 8; i++)
	{
		int digitVal = (value >> 28);
		value <<= 4;
		if (digitVal >= 10)
			printChar(digitVal - 10 + 'a');
		else
			printChar(digitVal + '0');
	}

	printChar('\n');
}

int main()
{
	printHex(fib(8));
	return 0;
}
