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



#include <stdio.h>
#include <string.h>

int __attribute__ ((noinline)) bar(char *buffer, int size)
{
	char tmp[size * 2];
	int index = 0;

	printf("enter bar\n");

	for (int i = 0; i < size; i++)
	{
		if (buffer[i] == 'i')
		{
			tmp[index++] = '~';
			tmp[index++] = 'i';
		}
		else
			tmp[index++] = buffer[i];
	}
	
	memcpy(buffer, tmp, index);
	return index;
}

int main()
{
	char foo[256] = "this is a test";
 
	int newLen = bar(foo, strlen(foo));
	for (int i = 0; i < newLen; i++)
		printf("%c", foo[i]);

	// CHECK: th~is ~is a test
}
