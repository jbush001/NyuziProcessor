#include "output.h"

Output output;

float a = 123.0;
int b = 79;
unsigned int c = 24;
unsigned int f = 0x81234000;

int main()
{
	float d = b;
	float e = c;
	float g = f;
	
	output << (int) a;			// CHECK: 0x0000007b
	output << (unsigned int) a;	// CHECK: 0x0000007b
	output << (int) d;			// CHECK: 0x0000004f
	output << (int) e;			// CHECK: 0x00000018
	output << (unsigned int) g;	// CHECK: 0x81234000
}
