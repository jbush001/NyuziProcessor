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

//
// Converts single-precision floating point numbers to an integer
//

module float_to_integer
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH,
	parameter SIGNIFICAND_PRODUCT_WIDTH = (SIGNIFICAND_WIDTH + 1) * 2)

	(input 										sign_i,
	input[EXPONENT_WIDTH - 1:0] 				exponent_i,
	input[SIGNIFICAND_PRODUCT_WIDTH - 1:0] 		significand_i,
	output reg [TOTAL_WIDTH - 1:0] 				result_o = 0);

	reg[TOTAL_WIDTH - 1:0]						unnormalized_result = 0;

	wire[5:0] shift_amount = (SIGNIFICAND_PRODUCT_WIDTH - (exponent_i - 127) - 2);
	wire[TOTAL_WIDTH - 1:0]	shifted_result = { {SIGNIFICAND_PRODUCT_WIDTH + 1{1'b0}},  
		significand_i } >> shift_amount;

	always @*
	begin
		if (exponent_i >= 127)	// Exponent is not negative
			unnormalized_result = shifted_result;
		else
			unnormalized_result = 0;
	end

	always @*
	begin
		if (exponent_i == 0 && sign_i == 0 && significand_i == 0)
			result_o = 0;
		else if (sign_i)
			result_o = ~unnormalized_result + 1;
		else
			result_o = unnormalized_result;
	end
endmodule
