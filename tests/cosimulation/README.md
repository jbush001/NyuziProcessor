This directory contains scripts and programs to verify the hardware design in 
co-simulation.  It works by executing a program in lock-step in the Verilog 
simulator and C based emulator. It compares instruction side effects and flags 
an error if they don't match. This works with both real programs and random 
instruction sequences created by the generate_random utility. 

Randomized cosimulation is a common processor verification technique. Here 
are a few papers that describe it's application in some commercial processors:

* [Functional Verification of a Multiple-issue, Out-of-Order, Superscalar Alpha Processor— The DEC Alpha 21264 Microprocessor](http://www.cs.clemson.edu/~mark/464/21264.verification.pdf) 
* [Functional Verification of the HP PA 8000 Processor](http://www.cs.clemson.edu/~mark/464/hp8000.verification.pdf) 
* [PicoJava II Verification Guide](http://www1.pldworld.com/@xilinx/html/pds/HDL/picoJava-II/docs/pj2-verif-guide.pdf)

# Executing Tests

You can execute a test using the runtest script, like this:

    ./runtest.py <filename>

&lt;filename&gt; can an assembly file (.s), which the test script will assemble 
before execution, or a hex memory image. 

_The cosimulator only works in single-core configurations._

To debug issues, it is often desirable to see the instructions.  llvm-objdump 
can generate a listing file like this:

    usr/local/llvm-nyuzi/bin/llvm-objdump --disassemble WORK/test.elf > test.dis

The program will generate a trace if you set the SIMULATOR_DEBUG_ARGS 
environment variable:

    EMULATOR_DEBUG_ARGS=-v ./runtest.sh ...

### Simulator Random Seed

Verilator is a 2-state simulator. While a single bit in a standard Verilog 
simulator can have 4 states: 0, 1, X, and Z, Verilator only supports 0 and 1. 
As an alternative, Verilator can set random values when the model assigns X 
or Z to signals.  This useful feature catches failures that wouldn't be 
visible in a normal Verilog simulator because of subtleties in how the Verilog
 specification defines the behavior of X and Z.  This paper 
 http://www.arm.com/files/pdf/Verilog_X_Bugs.pdf describes these issues.

However, this means the RTL model will run slightly differently each time 
because all signals are not explicitly initialized at reset (SRAMs, for example).  
When simulation starts, the program prints the random seed it is using:

<pre>
Random seed is 1405877782
</pre>

To reproduce an issue that is timing dependent, you can set the environment 
variable RANDSEED to the value that caused the failure:

    RANDSEED=1405877782 ./runtest.sh cache_stress.s

# Generating New Random Test Program
 
Random tests are not checked into the tree. Use the generate_random.py script 
in the cosimulation directory to generate random test programs

    ./generate_random.py [-o output file] [-n number of instructions] [-m number of files]

This program will write output to the file 'random.s' by default.  

The -m file allows generating multiple test files.  For example:

    ./generate_random.py -m 100

The test script can run these like this:

    ./runtest random*

## Instruction Selection for Random Program Generation
 
A completely unbiased random distribution of instructions doesn't give 
great coverage. For example, a branch squashes instructions in the pipeline.  
If the test program issues branches too often, it will mask issues with 
instruction dependencies. Also, if it uses the full range of 32 registers as 
operands and destinations of instructions, RAW dependencies between subsequent 
instructions will be unlikely.

For that reason, this uses _constrained_ random instruction generation.  It uses 
an instruction distribution that gives better hardware coverage. The probabilities 
for instructions are currently hard-coded in generate_random.py. It also imposes 
additional constraints to prevent improper program behavior:

### Branches

To avoid creating infinite loops, it only generates forward branches. 
Additionally, it only generates a branch of eight or fewer instructions to 
avoid skipping too much code.

### Memory accesses

If the test program used random register values for pointers, it would access 
invalid memory addresses. Instead, it reserves three registers to act as 
memory pointers, which it guarantees to be valid addresses.  s0/v0 points to 
the base of a shared region, which all strands may read from s1/v1 is the 
base of a private, per-thread region that all each thread may write to.  s2/v2 
is pointer into the private region, that the test program assigns at random 
intervals. This validates instruction RAW dependency checking for memory 
instructions.

The test generator chooses random offsets for memory access instructions, 
which hits different cache lines and generates a mix of L1/L2 cache misses 
and hits. The alignment of these regions a multiple of L2 cache size so 
that aliasing of the lines occurs.  This verifies L2 cache writebacks.

There is code in the Verilog testbench to copy all dirty L2 cache lines back to 
memory so the test script can compare them. The random test program does not 
explicitly flush them. The C model does not emulate the caches.

_Currently, the testbench does not support a thread reading from 
a cache line that another is writing to.  The emulator does not model the 
behavior of the store buffer, so it can't simulate this in a cycle accurate
manner yet._


# How it works
## Checking
 
The test program runs the verilog simulator with the +regtrace=1 flag, which 
causes it to print ASCII descriptions of instruction side effects to stdout. 
These include register writebacks and memory stores. Each line includes the 
PC and thread of the instruction, and register/address information specific 
to the instruction.

The emulator (tools/emulator) is a C program that simulates behavior of the 
instruction set. It parses the textual output from the Verilog simulator.  
While it could have used VPI to directly call into the emulator, it uses text 
output instead for simplicity.

Each time the emulator parses one of these operations, it steps the 
corresponding thread. It continues stepping until it encounters an instruction 
that has a side effect (branch instructions, for example, do not).  It then 
compares the side effect of the instruction with the result from the Verilog 
simulator and flags an error if there is a mismatch.

Some sequences of instructions may be order dependent. The emulator does 
not reproduce thread issue order. Instead, the scheme described above allows 
the Verilog simulator to control instruction ordering.

### Caveats
- The emulator does not model the behavior of the store buffer. Since the store 
buffer affects visibility of writes to other strands, this means the emulator 
can't accurately model reads/writes to the same cache lines from multiple threads. 
Thus, the random test generator currently reserves a separate write region for
each strand. 
- The random instruction generator does not generate floating point instructions. 
There are still a fair number of subtle rounding bugs in the floating point 
pipeline.