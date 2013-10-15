
void printChar(char c)
{
	*((unsigned volatile*) 0xffff0004) = c;
}

void printHex(unsigned int value)
{
	for (int i = 0; i < 8; i++)
	{
		int digitValue = value >> 28;
		value <<= 4;
		if (digitValue < 10)
			printChar(digitValue + '0');
		else 
			printChar(digitValue - 10 + 'a');
	}
}

volatile unsigned int* const HWBASE = (volatile unsigned int*) 0xffff0400;

enum HwRegs
{
	// Write address space
	kRegX1 = 0,
	kRegX2,
	kRegDX1,
	kRegDX2,
	kRegY,
	kRegHeight,
	kRegAction,

	// Read address space
	kRegStatus = 0,
	kRegMask,
	kRegPatchX,
	kRegPatchY
};

int main()
{
	// Set up triangle
	HWBASE[kRegX1] = 0x50000;
	HWBASE[kRegX2] = 0x60000;
	HWBASE[kRegDX1] = -0x8000;
	HWBASE[kRegDX2] = 0x8000;
	HWBASE[kRegY] = 2;
	HWBASE[kRegHeight] = 7;
	HWBASE[kRegAction] = 1;	// Setup
	
	// Read results
	do
	{
		if (HWBASE[kRegStatus] & 1)	// Valid?
		{
			printHex(HWBASE[kRegPatchX]);	
			printChar(' ');
			printHex(HWBASE[kRegPatchY]);	
			printChar(' ');
			printHex(HWBASE[kRegMask]);	
			printChar('\n');
		}
	}
	while (HWBASE[kRegStatus] & 2);	// Is the rasterizer still busy?

	return 0;
}