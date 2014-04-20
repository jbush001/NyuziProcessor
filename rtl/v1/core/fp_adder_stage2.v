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
// Stage 2 of the floating point addition pipeline
// - Select the higher exponent to use as the result exponent
// - Shift to align significands
// 

module fp_adder_stage2
	(input                                    clk,
	input                                     reset,
	input [5:0]                               add1_operand_align_shift,
	input [`FP_SIGNIFICAND_WIDTH + 2:0]       add1_significand1,
	input [`FP_SIGNIFICAND_WIDTH + 2:0]       add1_significand2,
	input [`FP_EXPONENT_WIDTH - 1:0]          add1_exponent1,
	input [`FP_EXPONENT_WIDTH - 1:0]          add1_exponent2,
	input                                     add1_exponent2_larger,
	output logic[`FP_EXPONENT_WIDTH - 1:0]    add2_exponent,
	output logic[`FP_SIGNIFICAND_WIDTH + 2:0] add2_significand1,
	output logic[`FP_SIGNIFICAND_WIDTH + 2:0] add2_significand2);

	logic[`FP_EXPONENT_WIDTH - 1:0] unnormalized_exponent_nxt; 

	// Select the higher exponent to use as the result exponent
	always_comb
	begin
		if (add1_exponent2_larger)
			unnormalized_exponent_nxt = add1_exponent2;
		else
			unnormalized_exponent_nxt = add1_exponent1;
	end

	// Arithmetic shift right to align significands
	wire[`FP_SIGNIFICAND_WIDTH + 2:0]  aligned2_nxt = 
		{ {`FP_SIGNIFICAND_WIDTH + 3{add1_significand2[`FP_SIGNIFICAND_WIDTH + 2]}}, 
		 add1_significand2 } >> add1_operand_align_shift;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			add2_exponent <= {(1+(`FP_EXPONENT_WIDTH-1)){1'b0}};
			add2_significand1 <= {(1+(`FP_SIGNIFICAND_WIDTH+2)){1'b0}};
			add2_significand2 <= {(1+(`FP_SIGNIFICAND_WIDTH+2)){1'b0}};
			// End of automatics
		end
		else
		begin
			add2_exponent <= unnormalized_exponent_nxt;
			add2_significand1 <= add1_significand1;
			add2_significand2 <= aligned2_nxt;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

