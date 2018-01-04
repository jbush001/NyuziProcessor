This directory contains all tests for this project. This contains tests both
for the core itself, as well as for tools and software libraries.

# Running Tests

In most directories is a script called 'runtest.py'. Invoking this with no
arguments will run all tests in that directory:

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

# Test Approach

The validation strategy for the hardware implementation is to use a variety
of tests types to exercise it at different levels. Tests fall into the following
categories:

1. **Module level hardware unit/integration tests** (tests/unit)

   These test individual verilog modules, or combinations of them. These are
   not intended to be comprehensive (which would make them brittle).
   Because they have visibility into internal signals, and cycle precise
   timing control, they are useful for testing cases that are difficult to verify
   at the software level, for example, that flushing a cache line clears its
   dirty bit so it won't write it again.
   
2. **System level directed functional tests** (tests/core)

   These are intended to be comprehensive, covering all major instruction forms,
   operations, exception types, etc. They are self checking and report a failure
   or success message. These don't stress the system or catch race conditions
   (most are single threaded), but validate functional correctness. These run both
   in Verilog simulation and FPGA.
   
3. **Constrained random cosimulation** (tests/cosimulation)

   A test script generates random assembly programs. These are constrained,
   both to produce valid programs that don't crash immediately and have better
   coverage. Every instruction side effect is checked against the emulator model.
   These are multithreaded and stress the design. They are useful for finding
   race conditions and other hazards. But, since the emulator is not cycle
   accurate, this can't validate timing sensitive use cases like synchronized
   load/stores. These can only run in Verilog simulation. There is more detail
   in the README in the cosimulation directory.
   
4. **Synthetic stress tests** (tests/stress)

   Complementary to the random tests, these validate operations that the former
   cannot easily like atomic accessses or MMU operation. They often use an internal
   pseudorandom number generator to control their operation. Checking is done
   after the test as run, usually via a memory dump. These can run in Verilog
   simulation or on FPGA.
   
5. **Whole program tests** (tests/whole-program, tests/kernel, tests/render)

   These are real-world programs that do something useful like compute a
   cryptographic hash. The test harness verifies them by comparing their
   output to expected values. These include everything from simple, single
   threaded programs to a full fledged kernel. Most can run both in Verilog
   simulation and on FPGA.

