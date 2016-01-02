# How to Contribute

Patches are welcome. This is a broad project with many components, both
software and hardware. Here are some examples of areas to help out, which are
by no means exhaustive:

1. Hardware - Improve performance, increase clock speed, reduce area, add new
   instructions or memory mapped fixed function blocks. Synthesize for other
   FPGAs or ASICs (fix errors, add build scripts and config files)
2. Verification - Create new tests and test frameworks, improve existing ones.
3. Compiler - Improve code generation, port other language frontends
   (especially parallel languages).
4. Tools - Improve and implement new profiling, visualization, and performance
   measurement tools.
5. Benchmarks - A variety of benchmarks help evaluate instruction set or
   microarchitectural tradeoffs. There are many libraries of parallel benchmarks
   that could be ported.
6. Software - Optimize or add capabilities to librender, implement a raytracer,
   port games or demo effects (which do double duty as a tests and benchmarks)

There is a more detailed list of potential feature ideas at:
https://trello.com/b/ywPdjo0A/nyuziprocessortasks

# Submitting Changes

Please read the sections about testing and coding style below. Larger
architectural changes or features should be proposed on the
[Mailing List](https://groups.google.com/forum/#!forum/nyuzi-processor-dev)

There are a number of [good pages](https://help.github.com/) on how to use github's standard pull
request workflow. Here is a brief summary of how to do this from the command line:

First, set up your repository:

1. Fork the repo: From the main page, press the 'fork' button in the upper
right corner: https://github.com/jbush001/NyuziProcessor

2. Clone this to your local machine (replacing YOUR-USERENAME below with your
github login) and the main project as an upstream so you can sync the latest
changes:

   ```
   git clone https://github.com/YOUR-USERNAME/NyuziProcessor
   git remote add upstream https://github.com/jbush001/NyuziProcessor
   ```

To submit a change:

1. Make sure your master branch is up to date if you haven't updated recently:

   ```
   git checkout master
   git pull upstream master
   ```

2. Make a new topic branch for each submission:

   ```
   git checkout -b my-new-feature
   ```

3. Make changes and check into your local repository.
4. Rebase the changes and squash them into one commit.

http://eli.thegreenplace.net/2014/02/19/squashing-github-pull-requests-into-a-single-commit

5. Push the change to your fork on github

   ```
   git push origin my-new-feature
   ```

6. Follow the instructions [here](https://help.github.com/articles/creating-a-pull-request)
to create a pull request:

When a pull request has been accepted, you can sync it to your master branch
as described in step 1 above.

# Testing Changes

When adding new features, add tests as necessary to the tests/cosimulation
directory. A README in that directory describes how. The 'make test' target
will run most tests and automatically report the results, but here are a few
other tests to run.

1. Create random cosimulation tests - Randomized tests aren't checked into the
tree, but it's easy to create a bunch and run them. From tests/cosimulation:


   ```
   $ ./generate_random.py -m 25
   generating random0000.s
   generating random0001.s
   ...
   $ ./runtest.sh random*.s
   Building random0000.s
   Random seed is 1411615265
   496347 total instructions executed
   PASS
   ```

2. Synthesize for FPGA - The Quartus synthesis tools catch different types of
errors than Verilator. It will also print some basic information about the
synthesized design after synthesis:

    Fmax 54.3 MHz
    73,034 Logic elmements

Ensure the frequence hasn't decreased too much (the design will not work on FPGA
if it is below 50 MHz), and that the number of logic elements hasn't increased
substantially.

4. For compiler and emulator changes, compile and execute run apps in software/apps.

# Coding Style

When in doubt, be consistent with existing code. Coding style adheres to that
used by autoformatting utilities, which I would recommend running on code before
submitting. To install:

    sudo apt-get install astyle
    pip install --upgrade autopep8

To reformat C/C++ code:

    astyle --style=allman --in-place *.cpp *.c *.h

To reformat Python code:

    autopep8 --in-place -r

Python scripts should be written to be compatible with both Python 2
and Python 3.

The OpenCores guidelines give a good set of rules for SystemVerilog sources,
which this project generally follows (with some exceptions, which should be
obvious)

http://cdn.opencores.org/downloads/opencores_coding_guidelines.pdf

This project also uses the following additional conventions:

- Use `logic` to define nets and flops rather than `reg` and `wire`
- For non-generic components, make the instance name be the same as the component name<br>
   No:

   ```SystemVerilog
   writeback_stage wback(
   ```

   Yes:

   ```SystemVerilog
   writeback_stage writeback_stage(
   ```

- Use verilog-2001 style port definitions, specifying direction and type in one
  definition. Group module ports by source/destination and add a comment for
  each group. Prefix signals that go between non-generic components with an
  abbreviation of the source module

   ```SystemVerilog
	// From io_request_queue
	input scalar_t                ior_read_value,
	input logic                   ior_rollback_en,

	// From control registers
	input scalar_t                cr_creg_read_val,
	input thread_bitmap_t         cr_interrupt_en,
	input scalar_t                cr_fault_handler,
   ```

- Instantiate srams using sram_1r1w and sram_2r1w
- Use always_ff and always_comb to avoid inferred latches or sensitivity list bugs.
- Signals often use the following suffixes:

   |Suffix|Meaning |
   |------|--------|
   | _en  | Use for a signal that enables some operation. Internal enables are always active high. |
   | _oh  | One-hot. No more than one signal will be set, corresponding to the index |
   | _idx | Signal is an index. Usually used when one-hot signals of the same name are also present |
   | _t   | Typedef |
   | _gen | Generated block |
   | _nxt | Combinational logic that generates the next value (input) for a flop.  Used to distinguish the input from the output of the flop |

- Don't use translate_off/translate on. Use ``ifdef SIMULATION` where necessary
  (this should be rare).
- Use unique and unique0 in front of case statements wherever appropriate. Don't use
  full_case/parallel_case pragmas.
- assert should only be inside an always_ff and shouldn't be reachable when reset
  is high. Otherwise it may trip incorrectly.
