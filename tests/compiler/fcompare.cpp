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



#include <stdio.h>

void __attribute__ ((noinline)) test_compare(float a, float b)
{
    printf("a > b %d\n", a > b);
    printf("a >= b %d\n", a >= b);
    printf("a < b %d\n", a < b);
    printf("a <= b %d\n", a <= b);
    printf("a == b %d\n", a == b);
    printf("a != b %d\n", a != b);
}

int main()
{
    float values[] = { -2.0f, -1.0f, 0.0f, 1.0f, 2.0f, 0.0f/0.0f };

    for (int i = 0; i < 5; i++)
    {
        for (int j = 0; j < 5; j++)
        {
            printf("%d %d ", i, j);
            test_compare(i, j);
        }
    }
}

// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0