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

struct TestCase
{
    enum {
        FADD,
        FSUB,
        FMUL,
        ITOF,
        FTOI,
        FGTR
    } operation;
    unsigned int value1;
    unsigned int value2;
    unsigned int expectedResult;
} TESTS[] = {
    #include "test_cases.inc"
};

float valueAsFloat(unsigned int value)
{
    union
    {
        float f;
        unsigned int i;
    } u = { .i = value };

    return u.f;
}

unsigned int valueAsInt(float value)
{
    union
    {
        float f;
        unsigned int i;
    } u = { .f = value };

    return u.i;
}

int main()
{
    int testIndex;
    unsigned int result;
    int numTestCases = sizeof(TESTS) / sizeof(struct TestCase);
    int failures = 0;

    for (testIndex = 0; testIndex < numTestCases; testIndex++)
    {
        struct TestCase *test = &TESTS[testIndex];

        switch (test->operation)
        {
            case FADD:
                result = valueAsInt(valueAsFloat(test->value1) + valueAsFloat(test->value2));
                break;
            case FSUB:
                result = valueAsInt(valueAsFloat(test->value1) - valueAsFloat(test->value2));
                break;
            case FMUL:
                result = valueAsInt(valueAsFloat(test->value1) * valueAsFloat(test->value2));
                break;
            case ITOF:
                result = valueAsInt((float)(int) test->value1);
                break;
            case FTOI:
                result = (unsigned int)(int) valueAsFloat(test->value1);
                break;
            case FGTR:
                result = (valueAsFloat(test->value1) > valueAsFloat(test->value2)) != 0;
                break;
        }

        if (result != test->expectedResult)
        {
            printf("test %d failed: expected %08x, got %08x\n", testIndex, test->expectedResult,
                result);
            failures++;
        }
    }

    if (failures == 0)
        printf("%d tests passed\n", numTestCases);
    else
        printf("%d/%d tests failed\n", failures, numTestCases);
}
