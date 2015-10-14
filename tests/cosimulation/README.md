This directory contains scripts and programs to verify the hardware design in
co-simulation. It executes programs in lock-step in the Verilog simulator and C
based emulator and compares instruction side effects. If they do not match, it
flags an error. This works with real programs and random instruction sequences
created by the generate_random utility.

Randomized cosimulation is a common processor verification technique. Here 
are a few papers that describe its application in some commercial processors:

* [Functional Verification of a Multiple-issue, Out-of-Order, Superscalar Alpha Processor— The DEC Alpha 21264 Microprocessor](http://www.cs.clemson.edu/~mark/464/21264.verification.pdf) 
* [Functional Verification of the HP PA 8000 Processor](http://www.cs.clemson.edu/~mark/464/hp8000.verification.pdf) 
* [PicoJava II Verification Guide](http://www1.pldworld.com/@xilinx/html/pds/HDL/picoJava-II/docs/pj2-verif-guide.pdf)

# Executing Tests

Execute a test using the runtest script, like this:

    ./runtest.py <filename>

&lt;filename&gt; can an assembly file (.s), which the test script assembles
before execution, or a hex memory image. 

The cosimulator only works in single-core configurations.

To debug problems, it is often desirable to see the instructions. llvm-objdump 
can generate a listing file like this:

    usr/local/llvm-nyuzi/bin/llvm-objdump --disassemble WORK/test.elf > test.dis

The program generates a trace if you set the SIMULATOR_DEBUG_ARGS 
environment variable:

    VERBOSE=1 ./runtest.py ...

### Simulator Random Seed

Verilator is a 2-state simulator. Whereas a single bit in a standard Verilog 
simulator can have 4 states: 0, 1, X, and Z, Verilator only supports 0 and 1. 
As an alternative, Verilator can set random values when the model assigns X 
or Z to signals. This can catch signals that are not initialized during reset.

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
in the cosimulation directory to generate random test programs

    ./generate_random.py [-o output file] [-n number of instructions] [-m number of files]

This program writes output to the file 'random.s' by default. 

The -m file allows generating multiple test files. For example:

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
is described in more detail below. It also imposes extra constraints so it
doesn't crash.

### Branches

To avoid infinite loops, it only generates forward branches. It also only 
branches less than eight instructions to avoid skipping too much code.

### Memory accesses

If the test program used random register values for pointers, it would access
addresses that unaligned or out of range. Instead, it reserves three registers
to act as memory pointers, which it guarantees to be valid addresses. s0/v0
points to the base of a shared region, which all threads may read from s1/v1 is
the base of a private, per-thread region that all each thread may write to.
s2/v2 is pointer into the private region, that the test program assigns at
random intervals. This validates instruction RAW dependency checking for memory
instructions.

The test generator chooses random offsets for memory access instructions, which
hits different cache lines and generates a mix of L1/L2 cache misses and hits.
The alignment of these regions a multiple of L2 cache size so that aliasing of
the lines occurs. This verifies L2 cache writebacks.

The Verilog testbench copies all dirty L2 cache lines back to memory at the end
of simulation so the test script can compare them. This is necesssary because 
the random test program does not flush them and The C model does not emulate 
the caches.

_The testbench does not support a thread reading from a cache line that another
is writing to. The emulator does not model the behavior of the store buffer, so
it can't simulate this in a cycle accurate manner yet._

# How it works
## Checking

The test program runs the verilog simulator with the +trace flag, which
causes it to print text descriptions of register writebacks and memory stores
to stdout. Each line includes the program counter and thread ID of the
instruction, and register/address information specific to the instruction.

The emulator (tools/emulator) is a C program that simulates behavior of the
instruction set. It reads the textual output from the Verilog simulator. Each
time the emulator parses one of these operations, it steps the corresponding
thread until it encounters an instruction that has a side effect (branch 
instructions, for example, do not). It then compares the side effect of the 
instruction with the result from the Verilog simulator and flags an error 
if there is a mismatch.

### Limitations
- The emulator does not model the behavior of the store buffer. As the store
  buffer affects visibility of writes to other threads, this means the emulator
  can't accurately model reads/writes to the same cache lines from multiple
  threads. Thus, the random test generator reserves a separate write region for
  each thread.
- The random instruction generator does not generate floating point
  instructions. There are still a fair number of subtle rounding bugs in the
  floating point pipeline.
