This is a set of whole-program compiler tests, similar to the
'test-suite' project in LLVM.  It compiles a program, then runs it in
the C simulator, capturing text output that is written to the hardware
register 0xFFFF0000. This is compared to regular expressions within the
program prefixed with 'CHECK:'.  This is similar to how DejaGnu or
llvm-lit works (although much simplified).

This can be run as follows:

    ./runtest.sh <program names>

For example:

    ./runtest.sh hello.cpp
    ./runtest.sh *.c

NOTE: this attempts to use the compiler that is installed at 
/usr/local/llvm-nyuzi/. When testing a compiler in development that
has not been installed, adjust COMPILER_DIR variable in the runtest.sh script to 
point at the build directory.

