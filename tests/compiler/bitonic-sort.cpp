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

// http://en.wikipedia.org/wiki/Bitonic_sorter

inline veci16_t butterfly(veci16_t items, vecu16_t shuffle, int direction)
{
	veci16_t swapped = __builtin_nyuzi_shufflei(items, shuffle);
	int compareResult = __builtin_nyuzi_mask_cmpi_slt(items, swapped);
	return __builtin_nyuzi_vector_mixi(compareResult ^ direction, items, swapped);
}

veci16_t bitonicSort(veci16_t items)
{
	const vecu16_t kSwapIndices1 = { 1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14 };
	const vecu16_t kSwapIndices2 = { 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13 };
	const vecu16_t kSwapIndices3 = { 4, 5, 6, 7, 0, 1, 2, 3, 12, 13, 14, 15, 8, 9, 10, 11 };
	const vecu16_t kSwapIndices4 = { 8, 9, 10, 11, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7 };

	items = butterfly(items, kSwapIndices1, 0b0110011001100110);
	items = butterfly(items, kSwapIndices2, 0b0011110000111100);
	items = butterfly(items, kSwapIndices1, 0b0101101001011010);
	items = butterfly(items, kSwapIndices3, 0b0000111111110000);
	items = butterfly(items, kSwapIndices2, 0b0011001111001100);
	items = butterfly(items, kSwapIndices1, 0b1010101001010101);
	items = butterfly(items, kSwapIndices4, 0b1111111100000000);
	items = butterfly(items, kSwapIndices3, 0b1111000011110000);
	items = butterfly(items, kSwapIndices2, 0b1100110011001100);
	items = butterfly(items, kSwapIndices1, 0b1010101010101010);

	return items;
}

int main()
{
	veci16_t testVector = { 21, 7, 37, 23, 19, 13, 11, 27, 29, 33, 9, 25, 31, 35, 17, 15 };
	veci16_t result = bitonicSort(testVector);
	for (int i = 0; i < 16; i++)
		printf("%u, ", result[i]);

	// CHECK: 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37

	return 0;
}
