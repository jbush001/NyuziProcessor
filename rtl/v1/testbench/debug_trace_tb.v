// 
// Copyright 2013 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

module debug_trace_tb;
	localparam CAPTURE_WIDTH_BITS = 32;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		uart_tx;		// From debug_trace of debug_trace.v
	// End of automatics
	reg clk;
	reg[CAPTURE_WIDTH_BITS - 1:0] capture_data;
	reg capture_enable;
	reg reset = 0;
	reg trigger = 0;

	debug_trace #(.CAPTURE_WIDTH_BITS(CAPTURE_WIDTH_BITS)) debug_trace(/*AUTOINST*/
									   // Outputs
									   .uart_tx		(uart_tx),
									   // Inputs
									   .clk			(clk),
									   .reset		(reset),
									   .capture_data	(capture_data[CAPTURE_WIDTH_BITS-1:0]),
									   .capture_enable	(capture_enable),
									   .trigger		(trigger));

	integer i;

	initial
	begin
		capture_enable = 0;
		clk = 0;
		reset = 1;
		#5 reset = 0;

		$dumpfile("trace.vcd");
		$dumpvars;
		
		// Clock in some data
		for (i = 0; i < 10; i = i + 1)
		begin
			capture_enable = i & 1;
			capture_data = 32'hdeadbeef + i;
			#5 clk = 1;
			#5 clk = 0;
		end
		#5 trigger = 1;

		for (i = 0; i < 1000; i = i + 1)
			#5 clk = !clk;
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// End:
