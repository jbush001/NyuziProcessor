This is a set of whole-program tests, like the 'test-suite' project in LLVM. It
runs programs it in the emulator and comparing the output to regular
expressions embedded in source code comments prefixed with 'CHECK:'. This is
similar to DejaGnu and llvm-lit. Each file is a standalone program.

Although this is primarily a compiler test, it also exercises the emulator and
hardware model. I've grabbed snippets of code from a variety of open source
projects to get coverage of different coding styles and idioms. 3rd party
programs retain their own licenses, which are indicated in the top of each
file. These tests are all single threaded.

To run all tests:

    ./runtest.py

To run a specific test:

    ./runtest.py *program names*

To run only on emulator:

    ./runtest.py --target emulator *program names*

* The test script skips filenames that begin with underscore, which is
  useful for known failing cases.
* This skips tests with "noverilator" in the filename (used for tests that
  take too long to run in verilator).
* Modify runtest.py to enable 'host' target, which will run on host machine.
  Some tests fail in this configuration because they use intrinsics
  that exist only for Nyuzi. TODO: should make this output CHECK comments with
  appropriate strings.
* The Csmith random generation tool generated The csmith* tests:
  http://embed.cs.utah.edu/csmith/
* This uses the compiler installed at /usr/local/llvm-nyuzi/. To test a
  development compiler, adjust COMPILER_DIR variable in test_harness.py
  in the parent directory.
