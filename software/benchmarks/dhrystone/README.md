This is a port of the [Dhrystone](https://en.wikipedia.org/wiki/Dhrystone)
benchmark for Nyuzi. The Dhrystone benchmark has a number of well-known problems:
- It's performance can vary widely due to compiler optimizations
- It calls into standard library functions like strcpy, so it's performance is also
  dependent on how optimized those implementations are.

It has additional issues when used against Nyuzi:
- It is single threaded. Nyuzi is optimized for multithreaded workloads. For example,
Nyuzi has a longer pipeline to improve clock speed, but relies on multiple threads to
keep it highly utilized.
- It has integer division in its loop. Nyuzi does not support hardware integer division,
but calls into a library routine to perform it, which is much slower.

There are two ways to run it:

The first form runs this in the emulator. The cycle counter on the emulator
represents it as a "perfect" machine that always issues one instruction per
cycle, so this test really validates the compiler.

    make run

The second form runs it against the hardware model:

    make verirun

I've made modifications to the original sources to get them to run on Nyuzi.
The changes are in the file nyuzi_changes.diff. They include:
- Hard code the number of runs instead of reading from stdin, since there
  is no stdin in this test environment and my standard library doesn't
  have scanf.
- Modified to use Nyuzi's get_cycle_count instead of time/times.
- Prints DMIPS/Mhz instead of Dhrystones per second, as the former is more
  appropriate in Verilog simulation.
