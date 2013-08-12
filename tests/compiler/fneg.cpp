#include "output.h"

Output output;

void printIt(float f)
{
	output << (int)(-f);
}

int main()
{
	printIt(192.0f);	// CHECK: 0xffffff40
	printIt(-189.0f);	// CHECK: 0x000000bd
}