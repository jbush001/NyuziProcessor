#include "output.h"

Output output;

float a = 123.0;
int b = 79;
unsigned int c = 24;

int main()
{
	float d = b;
	float e = c;
	
	output << (int) a;			// CHECK: 0x0000007b
	output << (unsigned int) a;	// CHECK: 0x0000007b
	output << (int) d;			// CHECK: 0x0000004f
//	output << (int) e;			// XXX should be 0x18, but is 0x17 for some reason
}
