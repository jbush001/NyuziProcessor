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
// order. This is similar to the bitonic-sort, but uses floats instead of ints.

vecf16_t sortedInsert(vecf16_t items, float value)
{
	const veci16_t kShiftMask = { 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 };
	int isGreater = __builtin_nyuzi_mask_cmpf_gt(items, (vecf16_t) value);
	items = __builtin_nyuzi_vector_mixf(isGreater, __builtin_nyuzi_shufflef(items, kShiftMask), items);
	return __builtin_nyuzi_vector_mixf(isGreater ^ (isGreater >> 1), vecf16_t(value), items);
}

int main()
{
	vecf16_t test = 1000000000.0;

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
		printf("%g, ", test[i]);

	// CHECK: 7.0, 9.0, 11.0, 13.0, 15.0, 17.0, 19.0, 21.0, 23.0, 25.0, 27.0, 29.0, 31.0, 33.0, 35.0, 37

	return 0;
}
