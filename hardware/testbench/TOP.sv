
// TOP module for VCS simulation.
// Compile with +initreg+random for random initialization (includes initialization to 0 and 1 -- special seeds)
// +initreg initializes both registers and memory
// Simulate with +initreg+<seed> to specify a seed
// Simulate with +initreg+0 to initialize to 0
// Simulate with +initreg+0 to initialize to 1

`include "defines.svh"

import defines::*;

module TOP();

   logic clk;
   logic reset;

   initial
     begin
        clk = '1;
        forever #1 clk = ~clk;
     end

   initial
     begin
        reset = '1;
        #11 reset = '0;
     end

   soc_tb soc_tb(.*);

   // Support for FSDB dumping

`ifndef FSDBFN
 `define FSDBFN "trace.fsdb"
`endif

   initial
     begin: DEBUSSY_SETUP
`ifdef DUMP_FSDB
        $display("Writing waveform to %s", `FSDBFN);
        $fsdbDumpfile(`FSDBFN);
        $fsdbDumpvars;
//      $fsdbDumpon;
`else
`endif
     end

endmodule
