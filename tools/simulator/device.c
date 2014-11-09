#include "core.h"

void writeDeviceRegister(unsigned int address, unsigned int value)
{
	if (address == 0x20)
		printf("%c", value & 0xff); // Serial output
}

unsigned readDeviceRegister(unsigned int address)
{
	switch (address)
	{
		case 0x18:	// Serial status
			return 1;

		// These dummy values match ones hard coded in the verilog testbench.
		// Used for validating I/O transactions in cosimulation.
		case 0x4:
			return 0x12345678;
		case 0x8:
			return 0xabcdef9b; 
		default:
			return 0xffffffff;
	}
}

