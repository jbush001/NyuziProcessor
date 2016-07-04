This directory contains scripts and programs to verify the hardware design in
co-simulation. It executes programs in lock-step in the Verilog simulator and C
based emulator and compares instruction side effects. If they do not match, it
flags an error. This works with real programs and random instruction sequences
created by the generate_random utility. Each file is a separate test.

Randomized cosimulation is a common processor verification technique. Here
are a few papers that describe its application in some commercial processors:

* [Functional Verification of a Multiple-issue, Out-of-Order, Superscalar Alpha Processor— The DEC Alpha 21264 Microprocessor](http://www.cs.clemson.edu/~mark/464/21264.verification.pdf)
* [Functional Verification of the HP PA 8000 Processor](http://www.cs.clemson.edu/~mark/464/hp8000.verification.pdf)
* [PicoJava II Verification Guide](http://www1.pldworld.com/@xilinx/html/pds/HDL/picoJava-II/docs/pj2-verif-guide.pdf)

# Executing Tests

To execute all tests in this directory, use the runtest script:

    ./runtest.py

To run a specific test, specify it on the command line

    ./runtest.py *filename*

These tests only work in single-core configurations.

To debug problems, it is often desirable to see the instructions. llvm-objdump
can generate a listing file like this:

    usr/local/llvm-nyuzi/bin/llvm-objdump --disassemble WORK/test.elf > test.dis

The program will print all events if you set the VERBOSE environment variable:

    VERBOSE=1 ./runtest.py ...

For example:

    swriteback 00000074 0 00 00000001
    00000074 [th 0] s0 <= 00000001
    swriteback 00000078 0 01 00000000
    00000078 [th 0] s1 <= 00000000
    swriteback 0000007c 0 02 ffffffff

The first line in this example is output from the verilator model, which can be the following:

    swriteback *program counter* *thread* *register* *value*
    vwriteback *program counter* *thread* *register* *mask* *value*
    store *program counter* *thread* *address* *mask* *value*

The second is output from the emulator.

    *pc* [th *thread*] *register*{*mask*} <= *value*
    *pc* [th *thread*] memory store size *size* *address* *value*

*Why are these different? Should probably clean this up*

### Simulator Random Seed

Verilator is a 2-state simulator. While a single bit in a standard Verilog
simulator can have 4 states: 0, 1, X, and Z, Verilator only supports 0 and 1.
To handle undefined values, Verilator sets random values when the model assigns
X to signals. This can catch flops that are not initialized during reset.

But this means the RTL model runs slightly differently each time because
not all signals are initialized at reset (SRAMs, for example). When simulation
starts, the program prints the random seed it is using:

<pre>
Random seed is 1405877782
</pre>

To reproduce an problem that is timing dependent, you can set the environment
variable RANDSEED to the value that caused the failure:

    RANDSEED=1405877782 ./runtest.py cache_stress.s

# Generating New Random Test Program

Random tests are not checked in. Use the generate_random.py script
in the cosimulation directory to create them:

    ./generate_random.py [-o output file] [-n number of instructions] [-m number of files]

It writes output to the file 'random.s' by default.

The -m flag generates multiple test files. For example:

    ./generate_random.py -m 100

The test script can run these like this:

    ./runtest.py random*

## Instruction Selection for Random Program Generation

An unbiased random distribution of instructions doesn't give great coverage.
For example, a branch squashes instructions in the pipeline. If the test program
issues branches too often, it will mask problems with instruction dependencies.
Also, if it uses the full range of 32 registers as operands and destinations of
instructions, RAW dependencies between instructions will be infrequent.

For that reason, this uses _constrained_ random instruction generation, which
is described in more detail below. It also imposes extra constraints so the
program doesn't crash.

### Branches

To avoid infinite loops, it only generates forward branches. It also only
branches fewer than eight instructions forward to avoid skipping too much
code.

### Memory accesses

If the test program used random register values for pointers, it would access
addresses that unaligned or out of range. Instead, it reserves three registers
to act as memory pointers, which it guarantees to be valid addresses. s0/v0
point to the base of a shared region, which all threads may read from s1/v1 is
the base of a private, per-thread region that all each thread may write to.
s2/v2 is pointer into the private region, that the test program assigns at
random intervals. This validates instruction RAW dependency checking for memory
instructions.

The test generator chooses random offsets for memory access instructions to
hit different cache lines and generates a mix of L1/L2 cache misses and hits.
The alignment of these regions a multiple of L2 cache size so that aliasing of
the lines occurs to cause L2 cache writebacks.

The Verilog testbench copies all dirty L2 cache lines back to memory at the end
of simulation so the test script can compare them. This is necesssary because
the random test program does not flush them and The C model does not emulate
the caches.

# How it works
## Checking

The test program runs the verilog simulator with the +trace flag, which
causes it to print text descriptions of register writebacks and memory stores
to stdout. Each line includes the program counter and thread ID of the
instruction, and register/address information specific to the instruction.

The emulator (tools/emulator) is a C program that simulates program execution.
It reads the textual output from the Verilog simulator. Each time it parses an
operation, it steps the corresponding thread until it encounters an instruction
that has a side effect (branch instructions, for example, do not). It then
compares the side effect of the instruction with the result from the Verilog
simulator and flags an error if there is a mismatch.

### Limitations

- The emulator does not model the behavior of the store buffer. As the store
  buffer affects visibility of writes to other threads, this means the emulator
  can't accurately model reads/writes to the same cache lines from multiple
  threads. Thus, the random test generator reserves a separate write region for
  each thread.
- The random instruction generator does not generate floating point
  instructions. There are still a fair number of subtle rounding bugs in the
  floating point pipeline.
- store_sync doesn't really work correctly with interrupts (even in the absence
  of thread contention), because the following can happen:
    1. Hardware executes store_sync, which fails. It does not log a cosimuation event
       because it *only* logs memory side effects, and those only occur on success
    2. Interrupt comes in. Emulator jumps to interrupt handler without executing the
	   store_sync and register does not get set to 0 to reflect failure.
- If control register 13 (subcycle) is read after an interrupt, it may not match the
  value in hardware, since hardware does not log scatter stores to lanes that don't
  have the mask bit set.
- This does not validate virtual memory translation. This has a software managed
TLB, and the TLB replacement behavior is timing specific, which makes it hard to match
behavior exactly.

