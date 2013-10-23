
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
	kRegY1,
	kRegX2,
	kRegY2,
	kRegX3,
	kRegY3,
	kRegAction,
	kRegEnable,
	kRegClipLeft,
	kRegClipTop,
	kRegClipRight,
	kRegClipBot,
	kRegClipEnable,

	// Read address space
	kRegStatus = 0,
	kRegMask,
	kRegPatchX,
	kRegPatchY
};

int main()
{
	// Set up triangle
	HWBASE[kRegClipLeft] = 4 << 16;
	HWBASE[kRegClipRight] = 15 << 16;
	HWBASE[kRegClipTop] = 0 << 16;
	HWBASE[kRegClipBot] = 15 << 16;
	HWBASE[kRegClipEnable] = 1;

	HWBASE[kRegX1] = 10 << 16;
	HWBASE[kRegY1] = 10 << 16;
	HWBASE[kRegX2] = 18 << 16;
	HWBASE[kRegY2] = 20 << 16;
	HWBASE[kRegX3] = 2 << 16;
	HWBASE[kRegY3] = 20 << 16;
    HWBASE[kRegEnable] = 1;	// Step to the next patch
		
	while (HWBASE[kRegStatus] & 2) {  // Keep looping until it's not busy
		if (HWBASE[kRegStatus] & 1)	// Valid?
		{
			printHex(HWBASE[kRegPatchX]);	
			printChar(' ');
			printHex(HWBASE[kRegPatchY]);	
			printChar(' ');
			printHex(HWBASE[kRegMask]);	
			printChar('\n');
		    HWBASE[kRegAction] = 1;	// Step to the next patch
		}
	}
	

	return 0;
}