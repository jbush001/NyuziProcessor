//
// DOOM Copyright Id Software
//

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

typedef int fixed_t;

#define FRACBITS				16
#define FRACUNIT				(1<<FRACBITS)
#define MININT			((int)0x80000000)		
#define MAXINT			((int)0x7fffffff)		


//
// FixedDiv, C version.
//

fixed_t
__attribute__ ((noinline)) FixedDiv2
( fixed_t		a,
  fixed_t		b )
{
	float c;

	c = ((float)a) / ((float)b) * FRACUNIT;
	if (c >= 2147483648.0 || c < -2147483648.0)
	{
		printf("FixedDiv: divide by zero");
		exit(1);
	}

	return (fixed_t) c;
}

fixed_t
__attribute__ ((noinline)) FixedDiv
( fixed_t		a,
  fixed_t		b )
{
	if ( (abs(a)>>14) >= abs(b))
		return (a^b)<0 ? MININT : MAXINT;
	return FixedDiv2 (a,b);
}

int main()
{
	// Check integer values that are inf/nan when
	// interpreted as floating point.
	printf("%08x\n", FixedDiv(0xff800000, 0xff800000));	// CHECK: 00010000
	printf("%08x\n", FixedDiv(0xff800000, 0xffa00000));	// CHECK: 00015555
	printf("%08x\n", FixedDiv(0xffa00000, 0xff800000));	// CHECK: 0000c000
	printf("%08x\n", FixedDiv(0xffa00000, 0xffa00000));	// CHECK: 00010000
}


	


