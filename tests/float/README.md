This test uses the Berkeley TestFloat package to verify the floating point implementation.
http://www.jhauser.us/arithmetic/TestFloat.html

Generating test cases:

    git clone https://github.com/ucb-bar/berkeley-softfloat-3.git
    make -C berkeley-softfloat-3/build/Linux-x86_64-GCC/
    git clone https://github.com/ucb-bar/berkeley-testfloat-3.git
    make -C berkeley-testfloat-3/build/Linux-x86_64-GCC/

The Linux build configuration works for MacOS, but I needed to modify platform.h in
berkeley-softfloat-3/build/Linux-x86_64-GCC/ and berkeley-testfloat-3/build/Linux-x86_64-GCC/
as follows:

    -#define INLINE extern inline
    +#define INLINE static inline

Generate test vectors:

    berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen f32_add > f32_add.test
    berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen f32_sub > f32_sub.test
    berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen f32_mul > f32_mul.test
    berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen i32_to_f32 > i32_to_f32.test
    berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen f32_to_i32 > f32_to_i32.test
    berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen f32_le > f32_le.test
    berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen f32_lt > f32_lt.test

Running tests natively on host:

    cc -o test_float test_float.c
    ./test_float

Run against emulator:

    make test

Run against hardware:

    make vtest
