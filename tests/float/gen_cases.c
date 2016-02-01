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

#define NUM_ELEMS(x) (sizeof(x) / sizeof(x[0]))
#define RAND_ELEM(x) x[rand() % NUM_ELEMS(x)]

unsigned int addFunc(unsigned int param1, unsigned int param2);
unsigned int subFunc(unsigned int param1, unsigned int param2);
unsigned int mulFunc(unsigned int param1, unsigned int param2);
unsigned int ftoiFunc(unsigned int param1, unsigned int param2);
unsigned int itofFunc(unsigned int param1, unsigned int param2);
unsigned int fgtrFunc(unsigned int param1, unsigned int param2);

//
// Floating point values are constrained so common edge cases are
// more common (for example, equal exponents)
//

unsigned int EXPONENTS[] = {
    0,
    1,
    100,    // -27
    125,    // -2
    126,    // -1
    127,    // 0
    128,    // 1
    129,    // 2
    154,    // 27
    254,
    255,    // Special
};

unsigned int SIGNIFICANDS[] = {
    0x000000,
    0x000001,
    0x000002,
    0x000010,
    0x000100,
    0x001000,
    0x010000,
    0x7ffffd,
    0x7ffffe,
    0x7fffff
};

struct Operation
{
    const char *name;
    unsigned int (*func)(unsigned int op1, unsigned int op2);
    int numOperands;
} OPS[] = {
    { "FADD", addFunc, 2 },
    { "FSUB", subFunc, 2 },
    { "FMUL", mulFunc, 2 },
    { "FGTR", fgtrFunc, 2 },
    { "ITOF", itofFunc, 1 },
    { "FTOI", ftoiFunc, 1 }
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

unsigned int addFunc(unsigned int param1, unsigned int param2)
{
    return valueAsInt(valueAsFloat(param1) + valueAsFloat(param2));
}

unsigned int subFunc(unsigned int param1, unsigned int param2)
{
    return valueAsInt(valueAsFloat(param1) - valueAsFloat(param2));
}

unsigned int mulFunc(unsigned int param1, unsigned int param2)
{
    return valueAsInt(valueAsFloat(param1) * valueAsFloat(param2));
}

unsigned int ftoiFunc(unsigned int param1, unsigned int param2)
{
    return (unsigned int)(int) valueAsFloat(param1);
}

unsigned int itofFunc(unsigned int param1, unsigned int param2)
{
    return valueAsInt((float)(int)param1);
}

unsigned int fgtrFunc(unsigned int param1, unsigned int param2)
{
    return valueAsFloat(param1) > valueAsFloat(param2);
}

unsigned int generateRandomValue(void)
{
    return (RAND_ELEM(EXPONENTS) << 23) | RAND_ELEM(SIGNIFICANDS)
        | ((rand() & 1) << 31);
}

int main()
{
    for (int opidx = 0; opidx < NUM_ELEMS(OPS); opidx++)
    {
        struct Operation *op = &OPS[opidx];
        for (int i = 0; i < 256; i++)
        {
            unsigned int value1 = generateRandomValue();
            unsigned int value2 = op->numOperands == 1 ? 0 : generateRandomValue();
            unsigned int result = op->func(value1, value2);

            if (op->func != ftoiFunc)
            {
                // Make NaN consistent
                if (((result >> 23) & 0xff) == 0xff && (result & 0x7fffff) != 0)
                    result = 0x7fffffff;
            }

            printf("{ %s, 0x%08x, 0x%08x, 0x%08x },\n", op->name,
                value1, value2, result);
        }
    }
}

