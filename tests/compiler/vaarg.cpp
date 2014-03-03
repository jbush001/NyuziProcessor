#include "Output.h"

Output output;

void varArgFunc(int numParams, ...)
{
	__builtin_va_list ap;
	__builtin_va_start(ap, numParams);

	for (int i = 0; i < numParams; i++)
		output << __builtin_va_arg(ap, int);
	
	__builtin_va_end(ap);
}

int main()
{
	varArgFunc(4, 0xaaaaaaaa, 0xbbbbbbbb, 0xcccccccc, 0xdddddddd);

	// CHECK: 0xaaaaaaaa
	// CHECK: 0xbbbbbbbb
	// CHECK: 0xcccccccc
	// CHECK: 0xdddddddd
}

