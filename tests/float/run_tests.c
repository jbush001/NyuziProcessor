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

//
// This executable runs on the target. It performs the operations in
// test_cases.inc and validates the computes results against the expected
// results encoded there.
//

enum operation {
    END = -1,
    FADD,
    FSUB,
    FMUL,
    ITOF,
    FTOI,
    FCMPLT
};

struct test_case
{
    unsigned int operation;
    unsigned int value1;
    unsigned int value2;
    unsigned int expected_result;
};

extern struct test_case TESTS[];

float value_as_float(unsigned int value)
{
    union
    {
        float f;
        unsigned int i;
    } u = { .i = value };

    return u.f;
}

unsigned int value_as_int(float value)
{
    union
    {
        float f;
        unsigned int i;
    } u = { .f = value };

    return u.i;
}

int main(void)
{
    int test_index;
    unsigned int result;
    int failures = 0;

    for (test_index = 0; ; test_index++)
    {
        struct test_case *test = &TESTS[test_index];
        if ((enum operation) test->operation == END)
            break;

        switch (test->operation)
        {
            case FADD:
                result = value_as_int(value_as_float(test->value1)
                    + value_as_float(test->value2));
                break;
            case FSUB:
                result = value_as_int(value_as_float(test->value1)
                    - value_as_float(test->value2));
                break;
            case FMUL:
                result = value_as_int(value_as_float(test->value1)
                    * value_as_float(test->value2));
                break;
            case ITOF:
                result = value_as_int((float)(int) test->value1);
                break;
            case FTOI:
                result = (unsigned int)(int) value_as_float(test->value1);
                break;
            case FCMPLT:
                result = (value_as_float(test->value1)
                    < value_as_float(test->value2)) != 0;
                break;
        }

        if (result != test->expected_result)
        {
            printf("test %d failed: expected %08x, got %08x\n", test_index + 1,
                test->expected_result, result);
            failures++;
        }
    }

    if (failures == 0)
        printf("%d tests passed\n", test_index);
    else
        printf("%d/%d tests failed\n", failures, test_index);
}
