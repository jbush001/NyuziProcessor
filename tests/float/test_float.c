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

int readValue(const char *ptr, unsigned int *outValue)
{
    int i;
    unsigned int value = 0;

    for (i = 0; i < 8; i++)
    {
        char c = ptr[i];
        if (c >= '0' && c <= '9')
            value = (value << 4) | (c - '0');
        else if (c >= 'a' && c <= 'f')
            value = (value << 4) | (c - 'a' + 10);
        else if (c >= 'A' && c <= 'F')
            value = (value << 4) | (c - 'A' + 10);
        else
            break;
    }

    *outValue = value;
    return i;
}

int readline(char *outLine, int maxLength, FILE *file)
{
    int length = 0;
    while (1)
    {
        int ch = fgetc(file);
        if (ch < 0)
            return -1;

        if (ch == '\r' || ch == '\n')
            break;

        if (length < maxLength - 1)
            outLine[length++] = ch;
    }

    outLine[length] = '\0';
    return length;
}

void runTestFile(const char *filename, int numParams, unsigned int (*testFunc)(unsigned int *params))
{
    char testLine[256];
    int currentLine;
    FILE *testFile;
    unsigned int params[3];
    int pindex;
    unsigned int computedValue;
    int testFailures = 0;
    const char *lineOffs;

    printf("Running test %s\n", filename);

    testFile = fopen(filename, "rb");
    if (testFile == NULL)
    {
        printf("Error opening test file %s\n", filename);
        return;
    }

    for (currentLine = 1; ; currentLine++)
    {
        if (readline(testLine, sizeof(testLine), testFile) < 0)
            break;

        lineOffs = testLine;
        for (pindex = 0; pindex < numParams; pindex++)
            lineOffs += readValue(lineOffs, &params[pindex]) + 1;

        computedValue = testFunc(params);
        if (computedValue != params[numParams - 1])
        {
            printf("%d: FAIL, expected %08x, got %08x\n", currentLine,
                params[numParams - 1], computedValue);
            testFailures++;
        }
    }

    printf("%s: %d/%d tests failed\n", filename, testFailures, currentLine - 2);
}

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

unsigned int testAdd(unsigned int *params)
{
    return valueAsInt(valueAsFloat(params[0]) + valueAsFloat(params[1]));
}

unsigned int testSub(unsigned int *params)
{
    return valueAsInt(valueAsFloat(params[0]) - valueAsFloat(params[1]));
}

unsigned int testMul(unsigned int *params)
{
    return valueAsInt(valueAsFloat(params[0]) * valueAsFloat(params[1]));
}

unsigned int testFloatToInt(unsigned int *params)
{
    return (unsigned int)(int) valueAsFloat(params[0]);
}

unsigned int testIntToFloat(unsigned int *params)
{
    return valueAsInt((float)(int)params[0]);
}

unsigned int testLessEqual(unsigned int *params)
{
    return valueAsFloat(params[0]) <= valueAsFloat(params[1]);
}

unsigned int testLessThan(unsigned int *params)
{
    return valueAsFloat(params[0]) < valueAsFloat(params[1]);
}

int main()
{
    runTestFile("f32_add.test", 3, testAdd);
    runTestFile("f32_sub.test", 3, testSub);
    runTestFile("f32_mul.test", 3, testMul);
    runTestFile("f32_le.test", 3, testLessEqual);
    runTestFile("f32_lt.test", 3, testLessThan);
    runTestFile("i32_to_f32.test", 2, testIntToFloat);

// Currently broken on host
//    runTestFile("f32_to_i32.test", 2, testFloatToInt);

}
