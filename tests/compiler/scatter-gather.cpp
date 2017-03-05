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

#include <stdint.h>
#include <stdio.h>

volatile unsigned int glob_array[16] = {
    100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115
};

int main()
{
  veci16_t values =   { 0, 1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 };
	veci16_t pointers = { 0, 3, 13, 15, 12, 10,  7,  1,  5, 11,  9, 14,  6,  2,  4,  8 };
  veci16_t gathered_ptrs;
  pointers <<= 2;
  pointers += int(&glob_array);

	__builtin_nyuzi_scatter_storei_masked(pointers, values, 0xffef);

	for (int i = 0; i < 16; i++)
		printf("%d ", glob_array[i]);

  // CHECK: 0 7 13 1 14 8 12 6 15 10 5 9 4 2 114 3

  printf("\n");
	gathered_ptrs = __builtin_nyuzi_gather_loadi_masked(pointers, 0xffff);
	for (int i = 0; i < 16; i++)
		printf("%d ", gathered_ptrs[i]);

  // CHECK: 0 1 2 3 4 5 6 7 8 9 10 114 12 13 14 15


}
