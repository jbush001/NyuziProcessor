// 
// Copyright (C) 2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

#include <ctype.h>
#include <stdlib.h>

static int randseed = -1;

void exit(int status) 
{
	asm("setcr s0, 31");
	while (1)
		;
}

void abort(void) 
{
	exit(0);
}

int abs(int value)
{
	if (value < 0)
		return -value;
	
	return value;
}

int atoi(const char *num)
{
	int value = 0;
	while (*num && isdigit(*num))
		value = value * 10 + *num++  - '0';

	return value;
}

int rand(void)
{
	return randseed * 1103515245 + 12345;
}

	
