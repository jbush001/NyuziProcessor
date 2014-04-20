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


//
// The integer multiplier has 3 cycles of latency.
// This is a stub for now.  It is intended to be replaced by something
// like a wallace tree.
//

module integer_multiplier(
	input                clk,
	input                reset,
	input [31:0]         multiplicand,
	input [31:0]         multiplier,
	output logic[47:0]   mult_product);
	
	logic[47:0] product1;
	logic[47:0] product2;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			mult_product <= 48'h0;
			product1 <= 48'h0;
			product2 <= 48'h0;
			// End of automatics
		end
		else
		begin
			product1 <= multiplicand * multiplier;
			product2 <= product1;
			mult_product <= product2;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

