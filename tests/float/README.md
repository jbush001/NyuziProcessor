This attempts to validate the hardware floating point implementation. It is inspired by
the [Berkeley TestFloat](http://www.jhauser.us/arithmetic/TestFloat.html) project,
but is much simpler and uses the host processor to generate results, unlike TestFloat
which uses a software floating point library to generate the results.

There are currently many failures when executing against Verilator, mostly caused by
rounding errors in hardware. All of the emulator tests should pass.

To execute against emulator:

    make test

To execute against verilator:

    make vtest

When there is a failure, it will print a message like this:

    test 21 failed: expected 00800ffd, got 00000ffd

----

Using Berkeley TestFloat to generate test cases

A bunch of these cases fail when using the emulator. For example, need to
convert results to a standard NaN representation (0x7fffffff)

1. Download testfloat and softfloat projects

        git clone https://github.com/ucb-bar/berkeley-testfloat-3.git
        git clone https://github.com/ucb-bar/berkeley-softfloat-3.git

2. Build (Linux and MacOS)

        make -C berkeley-softfloat-3/build/Linux-x86_64-GCC
        make -C berkeley-testfloat-3/build/Linux-x86_64-GCC

3. Create test vectors

        ./mk_testfloat_cases.sh

4. Run test program as before

        make test
