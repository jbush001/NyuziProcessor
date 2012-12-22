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

module fp_reciprocal_estimate(
	input [31:0] value_i,
	output [31:0] value_o);

	localparam EXPONENT_WIDTH = 8; 
	localparam SIGNIFICAND_WIDTH = 23;
	localparam LUT_WIDTH = 6;	// Must match size of reciprocal_rom
	localparam LH = 22;	// High bit index of lookup index
	localparam LL = LH - LUT_WIDTH + 1; // Low bit index of lookup index

	wire sign_i = value_i[31];
	wire[7:0] exponent_i = value_i[30:23];
	wire[22:0] significand_i = value_i[22:0];
	wire[LUT_WIDTH - 1:0] lut_value;
	reg value_o;

	reciprocal_rom rom(
		.addr_i(significand_i[LH:LL]),
		.data_o(lut_value));

	wire[EXPONENT_WIDTH - 1:0] result_exponent = 8'd253 - exponent_i 
		+ (significand_i[LH:LL] == 0);

	always @*
	begin
		if (exponent_i == 0 && significand_i == 0)
			value_o = { sign_i, 8'hff, 23'd0 };	// Division by zero = inf
		else if (exponent_i == 8'hff)
		begin
			if (significand_i)
				value_o = { 1'b0, 8'hff, 23'h400000 }; // Division by NaN = NaN
			else
				value_o = { sign_i, 8'h00, 23'h000000 }; // Division by +/-inf = +/-0.0
		end
		else 
			value_o = { sign_i, result_exponent, lut_value, {SIGNIFICAND_WIDTH - LUT_WIDTH{1'b0}} };
	end
endmodule
