// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
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
