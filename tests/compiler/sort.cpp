// 
// Copyright 2013 Jeff Bush
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

#include "output.h"

void sort(char *array, int length)
{
	for (int i = 0; i < length - 1; i++)
	{
		for (int j = i + 1; j < length; j++)
		{
			if (array[i] > array[j])
			{
				char tmp = array[i];
				array[i] = array[j];
				array[j] = tmp;
			}
		}	
	}
}

Output output;

int main()
{
	char tmp[11] = "atjlnpqdgs";
	sort(tmp, 10);

	for (int i = 0; i < 10; i++)
		output << tmp[i];

	output << "\n";

	// CHECK: adgjlnpqst
	
	return 0;
}
