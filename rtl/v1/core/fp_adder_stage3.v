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


`include "defines.v"

//
// Stage 3 of floating point addition pipeline
// - Add significands
// - Convert result back to signed magnitude form
// 

module fp_adder_stage3
	(input                                    clk,
	input                                     reset,
	input[`FP_SIGNIFICAND_WIDTH + 2:0]        add2_significand1,
	input[`FP_SIGNIFICAND_WIDTH + 2:0]        add2_significand2,
	output logic[`FP_SIGNIFICAND_WIDTH + 2:0] add3_significand,
	output logic                              add3_sign,
	input [`FP_EXPONENT_WIDTH - 1:0]          add2_exponent, 
	output logic[`FP_EXPONENT_WIDTH - 1:0]    add3_exponent);

	logic[`FP_SIGNIFICAND_WIDTH + 2:0] significand_nxt;
	logic sign_nxt;

	// Add
	wire[`FP_SIGNIFICAND_WIDTH + 2:0] sum = add2_significand1 + add2_significand2;

	// Convert back to signed magnitude
	always_comb
	begin
		if (sum[`FP_SIGNIFICAND_WIDTH + 2])
		begin
			significand_nxt = ~sum + 1;	
			sign_nxt = 1;
		end
		else
		begin
			significand_nxt = sum;
			sign_nxt = 0;
		end
	end
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			add3_exponent <= {(1+(`FP_EXPONENT_WIDTH-1)){1'b0}};
			add3_sign <= 1'h0;
			add3_significand <= {(1+(`FP_SIGNIFICAND_WIDTH+2)){1'b0}};
			// End of automatics
		end
		else
		begin
			add3_exponent <= add2_exponent;
			add3_sign <= sign_nxt;
			add3_significand <= significand_nxt;
		end
	end	
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

