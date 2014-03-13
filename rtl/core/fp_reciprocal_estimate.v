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
// Compute estimate for reciprocal using lookup table.  Has 6 bits of precision.
//

module fp_reciprocal_estimate(
	input [31:0]       value_i,
	output logic[31:0]   value_o);

	localparam LUT_WIDTH = 6;	// Must match size of reciprocal_rom
	localparam LH = 22;	// High bit index of lookup index
	localparam LL = LH - LUT_WIDTH + 1; // Low bit index of lookup index

	wire sign_i = value_i[31];
	wire[7:0] exponent_i = value_i[30:23];
	wire[22:0] significand_i = value_i[22:0];
	logic[LUT_WIDTH - 1:0] lut_value;

	reciprocal_rom rom(
		.addr_i(significand_i[LH:LL]),
		.data_o(lut_value));

	wire[`FP_EXPONENT_WIDTH - 1:0] result_exponent = 8'd253 - exponent_i 
		+ (significand_i[LH:LL] == 0);

	always_comb
	begin
		if (exponent_i == 0)
		begin
			// Any subnormal will effectively overflow the exponent field, so convert
			// to infinity (this also captures division by zero).
			value_o = { sign_i, 8'hff, 23'd0 }; // inf
		end
		else if (exponent_i == 8'hff)
		begin
			if (significand_i)
				value_o = { 1'b0, 8'hff, 23'h400000 }; // Division by NaN = NaN
			else
				value_o = { sign_i, 8'h00, 23'h000000 }; // Division by +/-inf = +/-0.0
		end
		else 
			value_o = { sign_i, result_exponent, lut_value, {`FP_SIGNIFICAND_WIDTH - LUT_WIDTH{1'b0}} };
	end
endmodule
