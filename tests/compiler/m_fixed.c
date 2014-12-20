// Emacs style mode select	 -*- C++ -*- 
//-----------------------------------------------------------------------------
//
// $Id:$
//
// Copyright (C) 1993-1996 by id Software, Inc.
//
// This source is available for distribution and/or modification
// only under the terms of the DOOM Source Code License as
// published by id Software. All rights reserved.
//
// The source is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// FITNESS FOR A PARTICULAR PURPOSE. See the DOOM Source Code License
// for more details.
//
// $Log:$
//
// DESCRIPTION:
//		Fixed point implementation.
//
//-----------------------------------------------------------------------------

#include <stdio.h>
#include <stdint.h>
#include <limits.h>


//
// Fixed point, 32bit as 16.16.
//
#define FRACBITS				16
#define FRACUNIT				(1<<FRACBITS)

typedef int fixed_t;



// Fixme. __USE_C_FIXED__ or something.

fixed_t
__attribute__ ((noinline)) FixedMul
( fixed_t		a,
  fixed_t		b )
{
	return ((long long) a * (long long) b) >> FRACBITS;
}



//
// FixedDiv, C version.
//

fixed_t
__attribute__ ((noinline)) FixedDiv
( fixed_t		a,
  fixed_t		b )
{
	if ( (abs(a)>>14) >= abs(b))
		return (a^b)<0 ? INT_MIN : INT_MAX;
	return FixedDiv2 (a,b);
}



fixed_t
__attribute__ ((noinline)) FixedDiv2
( fixed_t		a,
  fixed_t		b )
{
	double c;

	c = ((double)a) / ((double)b) * FRACUNIT;
	return (fixed_t) c;
}

int main()
{
	// Check integer values that are inf/nan when
	// interpreted as floating point.
	printf("%08x\n", FixedDiv(0xff800000, 0xff800000));	// CHECK: 00010000
	printf("%08x\n", FixedDiv(0xff800000, 0xffa00000));	// CHECK: 00015555
	printf("%08x\n", FixedDiv(0xffa00000, 0xff800000));	// CHECK: 0000c000
	printf("%08x\n", FixedDiv(0xffa00000, 0xffa00000));	// CHECK: 00010000

	uint64_t a = 1;
	int64_t b = -1;
	int64_t c = -1;

	for (int i = 0; i < 3; i++)
	{
		printf("a %08x%08x\n", (unsigned int)((a >> 32) & 0xffffffff), (unsigned int) (a & 0xffffffff));
		printf("b %08x%08x\n", (unsigned int)((b >> 32) & 0xffffffff), (unsigned int) (b & 0xffffffff));
		a = a * 13;
		b = b * 17;
		c = a * b;
		printf("c %08x%08x\n", (unsigned int)((c >> 32) & 0xffffffff), (unsigned int) (c & 0xffffffff));
	}

	printf("FixedMul %08x\n", FixedMul(0x009fe0c6, 0xfc4a8634));
	// CHECK: a 0000000000000001
	// CHECK: b ffffffffffffffff
	// CHECK: c ffffffffffffff23
	// CHECK: a 000000000000000d
	// CHECK: b ffffffffffffffef
	// CHECK: c ffffffffffff4137
	// CHECK: a 00000000000000a9
	// CHECK: b fffffffffffffedf
	// CHECK: c ffffffffff5b4c7b
	// CHECK: FixedMul af07b15d
}

