

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

void printChar(char c)
{
	*((volatile unsigned int*) 0xFFFF0004) = c;
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
}

void printVector(veci16 value)
{
	for (int i = 0; i < 16; i++)
	{
		printHex(value[i]);
		printChar(' ');
	}
	
	printChar('\n');
}

const veci16 kInc = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };

int main()
{
	veci16 a = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	for (int i = 0; i < 10; i++)
		a += kInc;

	printVector(a);

	return 0;
}
