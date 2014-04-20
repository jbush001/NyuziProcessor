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
// Given a floating point number that is not normalized (has the leading one
// and possibly some number of zeroes in front of it), output the same number in 
// normalized form, shifting the significand and adjusting the exponent.
//

module fp_normalize
	#(parameter INPUT_SIGNIFICAND_WIDTH = (`FP_SIGNIFICAND_WIDTH + 1) * 2)

	(input [INPUT_SIGNIFICAND_WIDTH - 1:0]    significand_i,
	output [`FP_SIGNIFICAND_WIDTH - 1:0]      significand_o,
	input [`FP_EXPONENT_WIDTH - 1:0]          exponent_i,
	output [`FP_EXPONENT_WIDTH - 1:0]         exponent_o,
	input                                     sign_i,
	output                                    sign_o);

	logic[5:0] highest_bit;
	logic[5:0] bit_index;

	// Find the highest set bit in the significand.  Infer a priority encoder.
	always_comb
	begin
		highest_bit = 0;
		for (bit_index = 0; bit_index < INPUT_SIGNIFICAND_WIDTH; bit_index++)
		begin
			if (significand_i[bit_index])
				highest_bit = bit_index;
		end
	end

	// Adjust the exponent
	wire[`FP_EXPONENT_WIDTH - 1:0] exponent_delta = (INPUT_SIGNIFICAND_WIDTH - highest_bit - 2);
	assign exponent_o = (highest_bit == 0) ? 0 : exponent_i - exponent_delta;

	// Shift the significand
	wire[5:0] shift_amount = INPUT_SIGNIFICAND_WIDTH - highest_bit;
	wire[INPUT_SIGNIFICAND_WIDTH - 1:0] shifter_result = significand_i << shift_amount;
	assign significand_o = shifter_result[`FP_SIGNIFICAND_WIDTH * 2 + 1:`FP_SIGNIFICAND_WIDTH + 2];
	assign sign_o = sign_i;
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
