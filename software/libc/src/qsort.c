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

#include <stdlib.h>

void qsort(void *base, size_t nel, size_t width, cmpfun cmp)
{
	unsigned int i, j, k;
	char tmp;
	
	if (nel == 0)
		return;
	
	for (i = 0; i < nel - 1; i++)
	{
		for (j = i + 1; j < nel; j++)
		{
			char *elem1 = (char*) base + i * width;
			char *elem2 = (char*) base + j * width;
			if (cmp(elem1, elem2) > 0)
			{
				// swap
				for (k = 0; k < width; k++)
				{
					tmp = elem1[k];
					elem1[k] = elem2[k];
					elem2[k] = tmp;
				}
			}
		}
	}
}


