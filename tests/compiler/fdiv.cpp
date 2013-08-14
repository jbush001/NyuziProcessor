#include "output.h"

Output output;

void printVal(float f)
{
	int foo;
	*((float*) &foo) = f;
	output << foo << "\n";
}

float a = 123.0;
float b = 11.1;
float c = 1.0;

int main()
{
	printVal(1.0f / a);		// CHECK: 0x3c053408
	printVal(1235.0f / b);	// CHECK: 0x42de85c3
	printVal(c / 0.4f);	// CHECK: 0x40200000
}
