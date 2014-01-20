## Overview
 
The test harness allows basic functional verification.  It runs a chunk
of assembly code in Verilog simulation and then verifies the register
and memory results at the end against a pre-defined set of expected
values.

## Running 
 
The test harness is located in tests/directed_verification. In order to run the 
tests, the verilog module must be compiled by switching to the verilog/ directory and
typing 'make' (the top level makefile will also do this).

The main python module that executes test cases is called 'runtest.py.' 
This can be invoked directly:

    ./runtest.py

When the test harness starts, it will scan all Python modules in the
directory.  Any classes that are derived from TestGroup will be scanned.
 Any methods within theses classs that begin with the prefix 'test_'
will added to the test case list.

If the app is invoked with no arguments, it will run all of the tests. 
If it is invoked with a specific test name (the method name without the
'test_' prefix), it will run just that test.  For example, if the method
name is test_loadStore, you can invoke it directly with:

    ./runtest.py loadStore

You can also invoke an entire group by using the class name.

_Note that these tests will not work properly with multiple cores
enabled (only one is enabled by default)_

## Test Implementation
 
Each test method returns a 5-tuple with the following fields:

### Initial Registers

A dictionary of initial register values. Each key is a register name,
which must start with a type 'u' for scalar or 'v' for vector types. 
Vector types must have an array of 16 values.  If the values are
negative integers or floating point values, they will be converted to
the proper values.

    { 'v9' : [ 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16], 'u7' : -34,
    'u11' : 3.13532
    }
    }
    
### Code

A snippet of code that will be assembled and executed.  The label
&#95;start may be defined as an entry point, but, if it is not,
execution will start at the first instruction.  Likewise, execution will
terminate after the last instruction in the list, but programs may
explicitly branch to the label &#95;&#95;&#95;done to terminate.

### Expected Register Values

Values of registers after the test has run.  These follow the same
formatting conventions as the initial registers.  Note that this only
needs to specify register values that have changed.  If a register is
set in the initial registers list and doesn't change, the test harness
will expect it to have the same value.

If a test doesn't care about the value of a specific register, it can
pass the value as None:

    { 'u3' : None }

If a test doesn't care about any registers, it can pass the entire
dictionary as None

### Memory Check

There are two parameters: a memory address and an array (of byte
values).  After the test runs, it will read those values from memory and
compare them.  If they do not match, it will return an error.  If these
fields are None, the memory check will be skipped.

## Debugging Test Failures

When a test failures, a diagnostic trace will be printed identifying the
source of the failure. 
* If waveform traces are needed, go into the Makefile
in the rtl/ directory, uncomment the line that sets VERILATOR_OPTIONS and
rebuild the verilog model (just type make).  A trace.vcd trace file will then 
be written into the directory.  This can be viewed using a waveform reader such as
[GTKWave](http://gtkwave.sourceforge.net/). 
* The environment variables SIMCYCLES=num cycles can be set if the test seems
to be hung.  This will cause the simulation to terminate the specified number of cycles.

It can be useful to see the context of the program being debugged. This can be done by
using llvm-objdump:

    /usr/local/llvm-vectorproc/bin/llvm-objdump --disassemble --symbolize WORK/program.elf

	Disassembly of section .text:
	_start:
	      74:	4a 3d 80 07                                  	move s10, 15
	      78:	5e 01 00 8c                                  	setcr s10, 30
	      7c:	5f f1 80 02                                  	add_i s10, pc, 60

The first column is the program counter address. The second four columns are
the raw instruction bytes. The remainder shows the instructions.

### Future Improvements

These tests should be merged into the same framework that the randomizer
uses, having the C reference model generate the appropriate expected
register and memory values.