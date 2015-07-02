This is a set of whole-program tests, like the 'test-suite' project in LLVM. It
runs programs it in the emulator, comparing the output to regular expressions
embedded in source code comments prefixed with 'CHECK:'. This is similar to how
DejaGnu or llvm-lit works.

Although this is primarily a compiler test, it also exercises the emulator and
hardware model. I've grabbed snippets of code from a variety of open source
projects to get coverage of different coding styles. These tests are
all single threaded.

Run the test using the runtest script:

    ./runtest.sh <program names>

For example:

    ./runtest.sh hello.cpp
    ./runtest.sh *.c

* Invoking runtest with no arguments runs all tests in the directory.
* The test script skips filenames that begin with underscore, which is
useful for known failing cases.
* Set the environment variable USE_VERILATOR to use the hardware model instead
  of the emulator. This skips tests with "noverilator" in the filename
  (used for tests that take too long to run in verilator).
* Set USE_HOSTCC to run on the host. This is useful for checking that the test
  is valid. Some tests fail in this configuration because they use intrinsics
  that exist only for Nyuzi. TODO: should make this output CHECK comments with
  appropriate strings.
* The Csmith random generation tool generated The csmith* tests: 
http://embed.cs.utah.edu/csmith/
* This uses the compiler installed at /usr/local/llvm-nyuzi/. To test a 
development compiler, adjust COMPILER_DIR variable in the runtest.sh script 
to point at the build directory.



