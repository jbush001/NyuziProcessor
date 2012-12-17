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
// Compute estimate for reciprocal using lookup table.  Has 6 bits of precision.
//

module fp_reciprocal_estimate
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input [31:0]						value_i,
	output [31:0]						value_o);

	localparam LUT_WIDTH = 6;	// Must match size of reciprocal_rom
	localparam LH = 22;
	localparam LL = LH - LUT_WIDTH + 1;

	wire sign_i = value_i[31];
	wire[7:0] exponent_i = value_i[30:23];
	wire[22:0] significand_i = value_i[22:0];
	wire[LUT_WIDTH - 1:0] lut_value;

	reciprocal_rom rom(
		.addr_i(significand_i[LH:LL]),
		.data_o(lut_value));

	// Note that, for the 0th entry in the table, we must add one to the exponent.
	wire[EXPONENT_WIDTH - 1:0] result_exponent = (exponent_i == 0 && significand_i == 0) 
		? 8'hff	// Division by zero, result is INF
		: 8'd253 - exponent_i + (significand_i[LH:LL] == 0);
	assign value_o = { sign_i, result_exponent, lut_value, {SIGNIFICAND_WIDTH - LUT_WIDTH{1'b0}} };
endmodule
