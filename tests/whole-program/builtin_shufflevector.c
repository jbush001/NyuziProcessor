//
// Copyright 2016 Jeff Bush
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
#include <stdint.h>

// Make these non-const so the optimizer won't remove the __builtin_shufflevector code.
veci16_t VECA = { 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52 };
veci16_t VECB = { 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68 };

void __attribute__ ((noinline)) printVector(veci16_t v)
{
	for (int lane = 0; lane < 16; lane++)
		printf("%d ", v[lane]);
}

// This test exercises various optimziations in the backend lowering code
int main(void)
{
    // Splat from first vector
    printf("\ntest 1: ");
    printVector(__builtin_shufflevector(VECA, VECB, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1));
        // CHECK: test 1: 38 38 38 38 38 38 38 38 38 38 38 38 38 38 38 38

    // Splat from second vector
    printf("\ntest 2: ");
    printVector(__builtin_shufflevector(VECA, VECB, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17));
        // CHECK: test 2: 54 54 54 54 54 54 54 54 54 54 54 54 54 54 54 54

    // Copy first vector
    printf("\ntest 3: ");
    printVector(__builtin_shufflevector(VECA, VECB, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15));
        // CHECK: test 3: 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52

    // Copy second vector
    printf("\ntest 4: ");
    printVector(__builtin_shufflevector(VECA, VECB, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31));
        // CHECK: test 4: 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68

    // Identity shuffle, converts to masked move
    printf("\ntest 5: ");
    printVector(__builtin_shufflevector(VECA, VECB, 0, 17, 2, 19, 4, 21, 6, 23, 8, 25, 10, 27, 12, 29, 14, 31));
        // CHECK: test 5: 37 54 39 56 41 58 43 60 45 62 47 64 49 66 51 68

    // Shuffle first vector only
    printf("\ntest 6: ");
    printVector(__builtin_shufflevector(VECA, VECB, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0));
        // CHECK: test 6: 52 51 50 49 48 47 46 45 44 43 42 41 40 39 38 37

    // Shuffle second vector only
    printf("\ntest 7: ");
    printVector(__builtin_shufflevector(VECA, VECB, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16));
        // CHECK: test 7: 68 67 66 65 64 63 62 61 60 59 58 57 56 55 54 53

    // Shuffle and mix both vectors
    printf("\ntest 8: ");
    printVector(__builtin_shufflevector(VECA, VECB, 31, 14, 29, 12, 27, 10, 25, 8, 23, 6, 21, 4, 19, 2, 17, 0));
        // CHECK: test 8: 68 51 66 49 64 47 62 45 60 43 58 41 56 39 54 37

    // Same vector is passed for both params
    printf("\ntest 9: ");
    printVector(__builtin_shufflevector(VECA, VECA, 31, 14, 29, 12, 27, 10, 25, 8, 23, 6, 21, 4, 19, 2, 17, 0));
        // CHECK: test 9: 52 51 50 49 48 47 46 45 44 43 42 41 40 39 38 37
}
