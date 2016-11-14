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
#include <stdlib.h>

int compare_int_values(const void *v1, const void *v2)
{
    return *((int*) v1) - *((int*) v2);
}

int __attribute__((noinline)) noinline_abs(int value)
{
    return abs(value);
}

int main()
{
    // abs
    printf("abs -17 %d\n", noinline_abs(-17));
    printf("abs 9 %d\n", noinline_abs(9));

    // atoi
    printf("atoi %d\n", atoi("1234")); // CHECK: atoi 1234

    // XXX atoi with negative number (not currently supported)

    // bsearch
    {
        const int values[13] = { 1, 2, 3, 4, 5, 6, 7, 15, 17, 19, 23, 27, 29 };
        int search_key;
        int *search_result;

        search_key = 1;
        search_result = (int*) bsearch(&search_key, values, 13, sizeof(int), compare_int_values);
        printf("bsearch 1 %d\n", (search_result - values));
        // CHECK: bsearch 1 0

        search_key = 6;
        search_result = (int*) bsearch(&search_key, values, 13, sizeof(int), compare_int_values);
        printf("bsearch 6 %d\n", (search_result - values));
        // CHECK: bsearch 6 5

        search_key = 17;
        search_result = (int*) bsearch(&search_key, values, 13, sizeof(int), compare_int_values);
        printf("bsearch 17 %d\n", (search_result - values));
        // CHECK: bsearch 17 8

        search_key = 29;
        search_result = (int*) bsearch(&search_key, values, 13, sizeof(int), compare_int_values);
        printf("bsearch 29 %d\n", (search_result - values));
        // CHECK: bsearch 29 12
    }
}
