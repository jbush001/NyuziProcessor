// 
// Copyright 2011-2012 Jeff Bush
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

`include "defines.v"

// 
// Given a floating point number that is not normalized (has the leading one
// and possibly some number of zeroes in front of it), output the same number in 
// normalized form, shifting the significand and adjusting the exponent.
//

module fp_normalize
	#(parameter INPUT_SIGNIFICAND_WIDTH = (`FP_SIGNIFICAND_WIDTH + 1) * 2)

	(input [INPUT_SIGNIFICAND_WIDTH - 1:0]   significand_i,
	output [`FP_SIGNIFICAND_WIDTH - 1:0]     significand_o,
	input [`FP_EXPONENT_WIDTH - 1:0]         exponent_i,
	output [`FP_EXPONENT_WIDTH - 1:0]        exponent_o,
	input                                    sign_i,
	output                                   sign_o);

	reg[5:0] highest_bit;
	reg[5:0] bit_index;

	// Find the highest set bit in the significand.  Infer a priority encoder.
	always @*
	begin
		highest_bit = 0;
		for (bit_index = 0; bit_index < INPUT_SIGNIFICAND_WIDTH; bit_index = bit_index + 1)
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

