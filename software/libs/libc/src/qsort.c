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


