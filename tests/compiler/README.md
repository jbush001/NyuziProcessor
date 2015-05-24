This is a set of whole-program tests, similar to the 'test-suite' project in 
LLVM. It compiles a program and runs it in the emulator, capturing text 
output. It then compares the output to regular expressions embedded in comments 
in the source code that are prefixed with 'CHECK:'. This is similar to how 
DejaGnu or llvm-lit works. Although this is primarily a compiler test, it
also exercises the emulator and hardware model. I've tried to grab snippets 
of code from a variety of open source projects to get coverage of different 
coding idioms and styles. These tests are all single threaded.

You can run the test using the runtest script:

    ./runtest.sh <program names>

For example:

    ./runtest.sh hello.cpp
    ./runtest.sh *.c

* Running the script with no arguments runs all tests in the directory.
* The test script skips filenames that begin with _  (used for known failing 
cases)
* If you set the environment variable USE_VERILATOR, it uses the hardware 
model instead of the emulator. If a filename has "noverilator" in it somewhere, 
it won't run the test in Verilator (this is used for tests that take too long 
to run in verilator)
* Setting USE_HOSTCC builds a host binary, useful for checking that the test
is valid. Some tests fail in this configuration because they use intrinsics that 
exist only for this architecture. TODO: should make this output CHECK comments 
with appropriate output. 
* The Csmith random generation tool generated The csmith* tests: 
http://embed.cs.utah.edu/csmith/
* This attempts to use the compiler installed at /usr/local/llvm-nyuzi/. 
When testing a compiler in development, adjust COMPILER_DIR variable in the 
runtest.sh script to point at the build directory.



