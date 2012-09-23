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
	(input [31:0]					value_i,
	output reg [31:0] 				result_o = 0);

	wire sign_i = value_i[31];
	wire[7:0] exponent_i = value_i[30:23];
	wire[23:0] significand_i = { 1'b1, value_i[22:0] };

	wire[5:0] shift_amount = 23 - (exponent_i - 127);
	wire[31:0] shifted_result = significand_i >> shift_amount;

	always @*
	begin
		if (exponent_i == 0 && sign_i == 0 && significand_i == 0)
			result_o = 0;
		else if (exponent_i < 127)	// Exponent negative (value smaller than zero)
			result_o = 0;
		else if (sign_i)
			result_o = ~shifted_result + 1;
		else
			result_o = shifted_result;
	end
endmodule
