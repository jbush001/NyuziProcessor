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

The test number in the message corresponds to the line in the 'test_cases.inc'
file.
