// 
// Copyright 2015 Jeff Bush
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

#include <stdint.h>
#include <stdio.h>

// Insert a single value into a vector of items, keeping the vector in ascending 
// order.
veci16_t sortedInsert(veci16_t items, int value)
{
	const veci16_t kShiftMask = { 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 };
	int isGreater = __builtin_nyuzi_mask_cmpi_sgt(items, __builtin_nyuzi_makevectori(value));
	items = __builtin_nyuzi_vector_mixi(isGreater, __builtin_nyuzi_shufflei(items, kShiftMask), items);
	return __builtin_nyuzi_vector_mixi(isGreater ^ (isGreater >> 1), __builtin_nyuzi_makevectori(value), 
		items);
}

int main()
{
	veci16_t test = __builtin_nyuzi_makevectori(0x7fffffff);

	test = sortedInsert(test, 21);
	test = sortedInsert(test, 7);
	test = sortedInsert(test, 37);
	test = sortedInsert(test, 23);
	test = sortedInsert(test, 19);
	test = sortedInsert(test, 13);
	test = sortedInsert(test, 11);
	test = sortedInsert(test, 27);
	test = sortedInsert(test, 29);
	test = sortedInsert(test, 33);
	test = sortedInsert(test, 9);
	test = sortedInsert(test, 25);
	test = sortedInsert(test, 31);
	test = sortedInsert(test, 35);
	test = sortedInsert(test, 17);
	test = sortedInsert(test, 15);

	for (int i = 0; i < 16; i++)
		printf("%u, ", test[i]);

	// CHECK: 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37
	
	return 0;
}
