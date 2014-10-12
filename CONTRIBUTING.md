# How to Contribute

Patches are welcome. This is a broad project with many components, 
both software and hardware. Here are some examples of areas to
help out, which are by no means exhaustive:

1. Hardware - Improve performance, increase clock speed, reduce area, 
   add new instructions or memory mapped fixed function blocks. Synthesize 
   for other FPGAs or ASICs (fix errors, add build scripts and config files)
2. Verification - Create new tests and test frameworks, improve existing ones.
3. Compiler - Improve code generation, port other language frontends 
   (especially parallel languages).
4. Tools - Improve and implement new profiling and performance measurement tools.
5. Benchmarks - A variety of benchmarks help evaluate instruction set or 
   microarchitectural tradeoffs. There are many libraries of parallel benchmarks
   that could be ported.
6. Software - Optimize or add capabilities to librender, implement a raytracer, 
   port games or demo effects (which do double duty as a tests and benchmarks)

There is a more detailed list of potential feature ideas at:
https://github.com/jbush001/NyuziProcessor/wiki/Backlog

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
4. Push the change to your fork on github

   ```
   git push origin my-new-feature
   ```
  
5. Follow the instructions [here](https://help.github.com/articles/creating-a-pull-request) 
to create a pull request: 

When a pull request has been accepted, you can sync it to your master branch
as described in step 1 above.

# Testing Changes

## Verilog 
When adding new features, add tests as necessary to the tests/cosimulation
directory. A README in that directory describes how. In addition, here are
standard tests that should be run to check for regressions:

1. Directed cosimulation tests - Switch to the tests/cosimulation directory

   ```
   $ ./runtest.sh *.s
   Building branch.s
   Random seed is 1411615294
   44 total instructions executed
   PASS
   ...
   ```

2. Random cosimulation tests - Randomized tests aren't checked into the 
tree, but it's easy to create a bunch and run them.  From tests/cosimulation:

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

3. 3D renderer - From the firmware/render-object directory, execute the renderer 
in verilog simulation. This can takes 4-5 minutes. Ensure it doesn't hang.
Open the fb.bmp file it spits out to ensure it shows a teapot.

   ```
   $ make verirun
   ...
  ***HALTED***
   ran for    16223433 cycles
   performance counters:
    l2_writeback                    56646
    l2_miss                        162023
   ...
   ```   
   
4. Synthesize for FPGA - The Quartus synthesis tools are more stringent 
than Verilator and catch additional errors and warnings.  Also:
 * Open rtl/fpga/de2-115/output_files/fpga_target.map.summary and check the 
 total number of logic elements to ensure the design still fits on the part 
 and the number of logic elements hasn't gone up excessively (it should be 
 around 73k)

   ```
   Analysis & Synthesis Status : Successful - Wed Sep 10 18:51:56 2014
   Quartus II 32-bit Version : 13.1.0 Build 162 10/23/2013 SJ Web Edition
   Revision Name : fpga_target
   Top-level Entity Name : fpga_top
   Family : Cyclone IV E
   Total logic elements : 73,327
   ```

 * Open rtl/fpga/de2-115/output_files/fpga_target.sta.rpt and find the maximum 
 frequency for clk50 to ensure the timing hasn't regressed (it should be around 
 60Mhz at 85C):

   ```
   +-----------------------------------------------------------+
   ; Slow 1200mV 85C Model Fmax Summary                        ;
   +------------+-----------------+---------------------+------+
   ; Fmax       ; Restricted Fmax ; Clock Name          ; Note ;
   +------------+-----------------+---------------------+------+
   ; 61.22 MHz  ; 61.22 MHz       ; clk50               ;      ;
   ...
   ```

## Simulator/Compiler

1. Run compiler tests - change to the tests/cosimulation directory

   ```bash
   $ ./runtest.sh 
   Testing atomic.cpp at -O0
   PASS
   Testing atomic.cpp at -O3 -fno-inline
   PASS
   ...
   ```

2. 3D renderer - This can be run under the simulator, which is much faster.  From
the firmware/3D-Renderer directory:

   ```bash
   $ make run
   ```

As above, ensure fb.bmp contains an image of a teapot.
 
There are instructions in the README for the [toolchain repository](https://github.com/jbush001/NyuziToolchain) 
on how to test the compiler using `llvm-lit`. 
 
# Coding Style

## Verilog
- Be consistent. When in doubt, look at formatting and style of other code.
- Use one module per file, the name of the file be the same as the name of the module.
- Indent with tabs, align with spaces
- All identifiers for modules and signals are lowercase and separated by underscores.  
Defines and parameters use uppercase separated by underscores.  Use concise but
descriptive names.  Don't abbreviate excessively.
- Use `logic` to define nets and flops rather than `reg` and `wire`
- Use verilog-2001 style port definitions, specifying direction and type in one definition:

   ```SystemVerilog
   module retry_controller(
       input[BIT_WIDTH - 1:0]   retry_count,
       output logic             retry);
   ```

- Keep the same signal name through hierarchies: Avoid renaming signals in port lists. 
Use .* for connections. The exception is generic components like an arbiter 
that is used in many places and have non-specific port names.<br>
   No:

   ```SystemVerilog
    writeback_stage writeback_stage(
        .writeback_en(do_writeback)
   ```

   Yes:

   ```SystemVerilog
    writeback_stage writeback_stage(
        .*
   ```

- For non-generic components, make the instance name be the same as the component name<br>
   No:

   ```SystemVerilog
   writeback_stage wback(
   ```

   Yes:

   ```SystemVerilog
   writeback_stage writeback_stage(
   ```

- Group module ports by source/destination and add a comment for each group
   
   ```SystemVerilog
	// From io_request_queue
	input scalar_t                ior_read_value,
	input logic                   ior_rollback_en,
	
	// From control registers
	input scalar_t                cr_creg_read_val,
	input thread_bitmap_t         cr_interrupt_en,
	input scalar_t                cr_fault_handler,
   ```

- Signals that go between non-generic components should be prefixed by an abbreviation of the source module:

   ```SystemVerilog
   module writeback_stage(
      output                     wb_fault,
      output fault_reason_t      wb_fault_reason,
      output scalar_t            wb_fault_pc,
   ```

- Use active high signals internally.
- Reset is active high, asynchronous. This avoids synthesizing extra multiplexers that impact fmax and increase area.
- All clocks are posedge triggered.  No multicycle paths.
- Instantiate srams using sram_1r1w and sram_2r1w
- Do not use tri-state signals internally
- Use always_ff and always_comb to avoid inferred latches or sensitivity list bugs.  Don't use latches deliberately.
- Global definitions are in defines.sv
- Signals often use the following suffixes:

   |Suffix|Meaning |
   |------|--------|
   | _en  | Use for a signal that enables some operation. Internal enables are always active high. |
   | _oh  | One-hot. No more than one signal will be set, corresponding to the index |
   | _idx | Signal is an index. Usually used when one-hot signals of the same name are also present |
   | _t   | Typedef |
   | _gen | Generated block |
   | _nxt | Combinational logic that generates the next value (input) for a flop.  Used to distinguish the input from the output of the flop |

- Don't use translate_off/translate on.  There is a macro SIMULATION that can be used
  where necessary (this should be rare).
- Use unique and unique0 in front of case statements wherever appropriate. Don't use
  full_case/parallel_case pragmas.
