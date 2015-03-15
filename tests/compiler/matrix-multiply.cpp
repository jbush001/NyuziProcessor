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


// This tests vector addition, multiplication, and shuffles

#include <stdint.h>
#include <stdio.h>

const veci16_t kShuffleA = { 0, 0, 0, 0, 4, 4, 4, 4, 8, 8, 8, 8, 12, 12, 12, 12 };
const veci16_t kShuffleB = { 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 };
const veci16_t kShuffleC = { 1, 1, 1, 1, 5, 5, 5, 5, 9, 9, 9, 9, 13, 13, 13, 13 };
const veci16_t kShuffleD = { 4, 5, 6, 7, 4, 5, 6, 7, 4, 5, 6, 7, 4, 5, 6, 7 };
const veci16_t kShuffleE = { 2, 2, 2, 2, 6, 6, 6, 6, 10, 10, 10, 10, 14, 14, 14, 14 };
const veci16_t kShuffleF = { 8, 9, 10, 11, 8, 9, 10, 11, 8, 9, 10, 11, 8, 9, 10, 11 };
const veci16_t kShuffleG = { 3, 3, 3, 3, 7, 7, 7, 7, 11, 11, 11, 11, 15, 15, 15, 15 };
const veci16_t kShuffleH = { 12, 13, 14, 15, 12, 13, 14, 15, 12, 13, 14, 15, 12, 13, 14, 15 };

vecf16_t multiplyMatrix(vecf16_t mat1, vecf16_t mat2)
{
	vecf16_t result = __builtin_nyuzi_shufflef(mat1, kShuffleA) * __builtin_nyuzi_shufflef(mat2, kShuffleB);
	result += __builtin_nyuzi_shufflef(mat1, kShuffleC) * __builtin_nyuzi_shufflef(mat2, kShuffleD);
	result += __builtin_nyuzi_shufflef(mat1, kShuffleE) * __builtin_nyuzi_shufflef(mat2, kShuffleF);
	result += __builtin_nyuzi_shufflef(mat1, kShuffleG) * __builtin_nyuzi_shufflef(mat2, kShuffleH);
	return result;
}

void printMatrix(vecf16_t value)
{
	for (int row = 0; row < 4; row++)
	{
		for (int col = 0; col < 4; col++)
			printf("%g ", value[row * 4 + col]);

		printf("\n");
	}
}

const vecf16_t kTestMat1 = { 
	1, 2, 7, 3,
	0, 3, -1, 1,
	3, 4, 2, -1,
	-2, 0, 9, 2
};

const vecf16_t kTestMat2 = { 
	3, 6, -2, 4,
	0, 3, 3, 1,
	7, 3, 1, 4,
	0, -3, 3, 2
};

int main()
{
	printMatrix(multiplyMatrix(kTestMat1, kTestMat2));

	// CHECK: 52.0 24.0 20.0 40.0
	// CHECK: -7.0 3.0 11.0 1.0
	// CHECK: 23.0 39.0 5.0 22.0
	// CHECK: 57.0 9.0 19.0 32.0
}
