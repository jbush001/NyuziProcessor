// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
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
