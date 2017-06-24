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

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

//
// This program runs on the host and generates test cases
// Floating point values are constrained so common edge cases are
// more common (for example, equal exponents)
//

#define NUM_ELEMS(x) (sizeof(x) / sizeof(x[0]))
#define RAND_ELEM(x) x[rand() % (int) NUM_ELEMS(x)]

unsigned int add_func(unsigned int param1, unsigned int param2);
unsigned int sub_func(unsigned int param1, unsigned int param2);
unsigned int mul_func(unsigned int param1, unsigned int param2);
unsigned int ftoi_func(unsigned int param1, unsigned int param2);
unsigned int itof_func(unsigned int param1, unsigned int param2);
unsigned int fcmplt_func(unsigned int param1, unsigned int param2);

static unsigned int EXPONENTS[] = {
    0,
    1,
    100,    // -27
    125,    // -2
    126,    // -1
    127,    // 0
    128,    // 1
    129,    // 2
    154,    // 27
    254
};

static unsigned int SIGNIFICANDS[] = {
    // Test various bit positions
    0x000000,
    0x000001,
    0x000002,
    0x000010,
    0x000100,
    0x001000,
    0x010000
};

static struct operation
{
    int index;  // Must match indices in run_tests.c
    const char *operator;
    unsigned int (*func)(unsigned int op1, unsigned int op2);
    int num_operands;
} OPS[] = {
    { 0, "+", add_func, 2 },
    { 1, "-", sub_func, 2 },
    { 2, "*", mul_func, 2 },
    { 3, "itof", itof_func, 1 },
    { 4, "ftoi", ftoi_func, 1 },
    { 5, "<", fcmplt_func, 2 }
};

unsigned int make_float(unsigned int sign, unsigned int exponent, unsigned int significand)
{
    return (sign << 31) | ((exponent & 0xff) << 23) | (significand & 0x7fffff);
}

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

    // x86 at least propagates NaN as recommended (but not required) by IEEE754,
    // but Nyuzi uses a consistent NaN representation for simplicity.
    if (isnan(value))
        return 0x7fffffff;

    return u.i;
}

void write_test_case(struct operation *op, unsigned int value1, unsigned int value2)
{
    unsigned int result = op->func(value1, value2);
    if (op->func == itof_func)
    {
        printf(".long %d, 0x%08x, 0, 0x%08x # %s %u = %+g\n", op->index,
            value1, result, op->operator, value1, (double) value_as_float(result));
    }
    else if (op->func == ftoi_func)
    {
        printf(".long %d, 0x%08x, 0, 0x%08x # %s %g = %u\n", op->index,
            value1, result, op->operator, (double) value_as_float(value1),
            result);
    }
    else if (op->num_operands == 1)
    {
        printf(".long %d, 0x%08x, 0, 0x%08x # %s %+g = %+g\n", op->index,
            value1, result, op->operator, (double) value_as_float(value1),
            (double) value_as_float(result));
    }
    else
    {
        printf(".long %d, 0x%08x, 0x%08x, 0x%08x # %+g %s %+g = %+g\n", op->index,
            value1, value2, result, (double) value_as_float(value1),
            op->operator, (double) value_as_float(value2),
            (double) value_as_float(result));
    }
}

unsigned int add_func(unsigned int param1, unsigned int param2)
{
    return value_as_int(value_as_float(param1) + value_as_float(param2));
}

unsigned int sub_func(unsigned int param1, unsigned int param2)
{
    return value_as_int(value_as_float(param1) - value_as_float(param2));
}

unsigned int mul_func(unsigned int param1, unsigned int param2)
{
    return value_as_int(value_as_float(param1) * value_as_float(param2));
}

unsigned int ftoi_func(unsigned int param1, unsigned int param2)
{
    (void) param2;

    return (unsigned int)(int) value_as_float(param1);
}

unsigned int itof_func(unsigned int param1, unsigned int param2)
{
    (void) param2;

    return value_as_int((float)(int)param1);
}

unsigned int fcmplt_func(unsigned int param1, unsigned int param2)
{
    return value_as_float(param1) < value_as_float(param2);
}

unsigned int generate_random_value(void)
{
    return (RAND_ELEM(EXPONENTS) << 23) | RAND_ELEM(SIGNIFICANDS)
        | ((unsigned int) (rand() & 1) << 31);
}

void test_add_sub_rounding(void)
{
    unsigned int sigidx;
    unsigned int GRS_SIGNIFICANDS[] = {
        // Last three bits are 000-111. This represents all values of GRS
        0x3ff0,
        0x3ff1,
        0x3ff2,
        0x3ff3,
        0x3ff4,
        0x3ff5,
        0x3ff6,
        0x3ff7,

        // Same as above, but with least significant bit in
        // non-shifted portion as 1 instead of zero to check
        // even/odd rounding cases
        0x3ff8,
        0x3ff9,
        0x3ffa,
        0x3ffb,
        0x3ffc,
        0x3ffd,
        0x3ffe,
        0x3fff
    };

    for (sigidx = 0; sigidx < NUM_ELEMS(GRS_SIGNIFICANDS); sigidx++)
    {
        // Because value2 has a smaller exponent, its lowest three digits
        // will be shifted out during alignment and become the guard, round,
        // and sticky bits. We then test all cases with add and subtract
        // to ensure rounding is handled correctly.
        unsigned int value2 = make_float(0, 125, GRS_SIGNIFICANDS[sigidx]);

        // Try two odd and even values for the first significand.
        for (unsigned int sig1 = 0xfffc; sig1 < 0x10000; sig1++)
        {
            unsigned int value1 = make_float(0, 128, sig1);
            write_test_case(&OPS[0], value1, value2);
            write_test_case(&OPS[1], value1, value2);
        }
    }
}

void test_specials(void)
{
    const float VALUES[] = {
        -INFINITY,
        -1.0,
        0x80000000,
        +0.0,
        +1.0,
        +INFINITY,
        NAN
    };
    unsigned int i, j;

    for (i = 0; i < NUM_ELEMS(VALUES); i++)
    {
        for (j = 0; j < NUM_ELEMS(VALUES); j++)
        {
            write_test_case(&OPS[0], value_as_int(VALUES[i]), value_as_int((VALUES[j])));   // add
            write_test_case(&OPS[1], value_as_int(VALUES[i]), value_as_int((VALUES[j])));   // sub
            write_test_case(&OPS[2], value_as_int(VALUES[i]), value_as_int((VALUES[j])));   // mul
        }
    }
}

void test_random(void)
{
    unsigned int opidx;

    for (opidx = 0; opidx < NUM_ELEMS(OPS); opidx++)
    {
        struct operation *op = &OPS[opidx];
        for (int i = 0; i < 1000; i++)
        {
            unsigned int value1 = generate_random_value();
            unsigned int value2 = op->num_operands == 1 ? 0 : generate_random_value();
            write_test_case(op, value1, value2);
        }
    }
}

int main(void)
{
    printf(".data\n");
    printf(".globl TESTS\n");
    printf("TESTS:\n");
    test_add_sub_rounding();
    test_specials();
    test_random();
    printf(".long -1");
}
