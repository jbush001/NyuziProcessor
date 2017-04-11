[Csmith](https://embed.cs.utah.edu/csmith/) is a tool that generates random
C programs, which can be useful to test the compiler toolchain and emulator.

Download latest version here:

    git clone https://github.com/csmith-project/csmith.git

Extract to a directory and build.

    cd csmith/
    ./configure
    make
    sudo make install

To generate and run tests:

    ./runtest.py

The tests operate by first compiling and executing the program on the host
and comparing the results to the output from the emulator.

This often fails because it generates large functions and the constant pool
is out of range of PC relative addressing:

    Compilation failed:
    fatal error: error in backend: fixup out of range

