// 
// Copyright 2011-2015 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
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

	
