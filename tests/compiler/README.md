This is a set of whole-program tests, similar to the 'test-suite' project in LLVM. 
It compiles a program, then runs it in the functional simulator, capturing text output. 
This is compared to regular expressions embbeded in comments in the program, prefixed with
'CHECK:'. This is similar to how DejaGnu or llvm-lit works (although much simpler). 

This can be run as follows:

    ./runtest.sh <program names>

For example:

    ./runtest.sh hello.cpp
    ./runtest.sh *.c

* Running the script with no arguments will run all programs in the directory.
* If you set the environment variable USE_VERILATOR, it will use the hardware model
instead of the functional simulator.
* The csmith* tests were generated with the Csmith random generation tool: http://embed.cs.utah.edu/csmith/
* This attempts to use the compiler that is installed at /usr/local/llvm-nyuzi/. 
When testing a compiler in development that has not been installed, adjust 
COMPILER_DIR variable in the runtest.sh script to point at the build directory.

Although this is nominally a compiler test, it also exercises the simulator or
hardware model. I've tried to grab snippets of code from a variety of open 
source projects to get good coverage of different coding idioms and styles.



