This directory contains software that runs on the Nyuzi processor. It includes
libraries, apps, and benchmarks.

## Running Applications

Most programs in the apps directory support the following targets, which will
compile the program if needed before executing it.

- **run**: Execute the program in the emulator. This will pop up a
  framebuffer window to display output if necessary.
- **verirun**: Execute the program in the Verilator verilog simulator, which
  is the default simulator that is installed by the install scripts. This
  does not support a framebuffer, so you may need to make modifications to the
  program to make it dump its output and stop after rendering one frame.
- **fpgarun**: Transfer it over the serial port to the FPGA board. Instructions
  for setting up the FPGA are in hardware/fpga/de2-115/README.
- **debug**: Execute the program in the emulator and attach to it with the
  debugger (lldb).
- **vcsrun**: Execute program in
  [VCS](https://www.synopsys.com/verification/simulation/vcs.html) Verilog
  simulator if you have it installed.

For example:

    make run
