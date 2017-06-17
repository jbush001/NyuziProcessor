#!/bin/bash

TESTGEN=berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen
echo $'.data\n.globl TESTS\nTESTS:' > test_cases.s

$TESTGEN f32_add | awk '{print ".long 0, 0x" $1 ", 0x" $2 ", 0x" $3}' >> test_cases.s
$TESTGEN f32_sub | awk '{print ".long 1, 0x" $1 ", 0x" $2 ", 0x" $3}' >> test_cases.s
$TESTGEN f32_mul | awk '{print ".long 2, 0x" $1 ", 0x" $2 ", 0x" $3}' >> test_cases.s
$TESTGEN i32_to_f32 | awk '{print ".long 3, 0x" $1 ", 0, 0x" $2}' >> test_cases.s
$TESTGEN f32_to_i32 | awk '{print ".long 4, 0x" $1 ", 0, 0x" $2}' >> test_cases.s

echo '.long -1' >> test_cases.s
