# Running Tests

This directory contains tests for all components in this repository. In most
directories is a script called 'runtest.py'. Invoking this with no arguments
will run all tests in that directory:

    ./runtest.py

To run a specific test, invoke this with the name of the test(s):

    ./runtest.py jtag_idcode jtag_bypass

By default, tests will be run on 'verilator' and 'emulator' targets if they
are supported by the test. This can be restricted to a specific target with the
--target flag:

    ./runtest.py --target emulator aes.c

The --debug flag will enable printing test specific diagonostic output to the
console.

There is an experimental 'fpga' target in progress, but is not fully functional'

Invoking the top level Makefile with the test target will run tests in subprojects.
This is executed by the continuous integration environment.

   make test

The Makefile does not run the following tests:

| Test Name            | Reason       |
|----------------------|--------------|
| stress/mmu/          | Takes a while to run, skipped to keep continuous integration tests quick.
| lldb/                | LLDB is not installed in the CI environment's container. |
| core/multicore/      |  Requires modifying hardware model to have 8 cores and rebuilding.
| csmith/              | Running on a 64-bit host produces different checksums than the program running on Nyuzi because of differences in native word width. Can still be useful to detect compiler crashes. |
| fail/                | These test cases validate the test harness itself and are meant to produce failure results. |
| float/               | Floating point conformance tests. There are still bugs in the hardware implementation that need to be fixed, and there are tweaks required to the test vectors to find canonical values where the spec is lenient. |
| fpga/                | These only run in the FPGA environment and validate things specific to the dev board (the test target only assembles them) |
| kernel/crash/        | Intermittently timing out, potentially because of a bug
| kernel/globalinit/   | For the following, it takes a while to run in verilator mode, so I skip for the sake of speed.
| kernel/hello/        |
| kernel/panic/        |
| kernel/user_copy_fault/ |
| kernel/initdata/     |
| kernel/multiprocess/ | These do not have automated harnesses and are not easy to
| kernel/threads/      |   automate for a number of reasons.
| kernel/vga/          |
| render/              | These only run under the emulator (they support verilator, but they take a long time to run)


# Adding Tests

Each test consists of a function, which takes two arguments: the name parameter (which
is useful to allow a function to support multiple tests), and a string target name which
controls how to execute the test (for example, on verilator or the emulator).
There are a few ways to add a new test. The easiest is to uses the 'test' decorator:

    @test_harness.test
    def frobulate(name, target):

This can include a parameter of which environments the test supports (by default, it will
support all):

    @test_harness.test(['emulator'])

Tests can also be added manually with several convenience functions:

    test_harness.register_tests(my_test_func, ['my_test'], ['emulator'])

At the bottom of each runtests.py, call into test_harness to invoke all tests that
are enabled:

    test_harness.execute_tests()

If the test fails, it should throw a TestException, with a useful description:

    if response != str.encode(value):
        raise test_harness.TestException(
            'unexpected response. Wanted ' + value + ' got ' + str(response))

There are a number of built-in functions to check output:

    def check_result(source_file, program_output):

This will open 'source_file' and scan through it looking for the patterns CHECK and CHECKN.
These will verify that the outputput string following it either occurs in program_output or
does not, respectively. Check patterns can be embedded in comments. This is usually used
on the output of the program. For example:

    printf("s1a 0x%08x\n", s1.a); // CHECK: s1a 0x12345678

If you'd like to add additional debugging output to a test, check the global DEBUG
flag, which will be set to true if the user adds --debug to the command line.

