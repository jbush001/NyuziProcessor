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

	localparam 							LUT_WIDTH = 6;

	wire sign_i = value_i[31];
	wire[7:0] exponent_i = value_i[30:23];
	wire[22:0] significand_i = value_i[22:0];

	wire[LUT_WIDTH - 1:0] lut_result;

	reciprocal_rom rom(
		.addr_i(significand_i[22:(22 - LUT_WIDTH + 1)]),
		.data_o(lut_result));

	reg[SIGNIFICAND_WIDTH - 1:0] significand_nxt;
	reg[EXPONENT_WIDTH - 1:0] exponent_nxt;

	always @*
	begin
		// XXX handle division by inf, nan
	
		if (exponent_i == 0)
		begin
			// division by zero, result is inf.
			significand_nxt = 0;
			exponent_nxt = 8'hff;
		end
		else if (significand_i == 0)
		begin
			// This would exceed the size of the output in the ROM table, since
			// this is the only entry with an extra bit.  Treat that special here.
			significand_nxt = {SIGNIFICAND_WIDTH{1'b0}};
			exponent_nxt = 8'd253 - exponent_i + 1;
		end
		else
		begin
			// Add the leading one explicitly.
			significand_nxt = { lut_result, {SIGNIFICAND_WIDTH - LUT_WIDTH{1'b0}} };
			exponent_nxt = 8'd253 - exponent_i;
		end
	end
	
	assign value_o = { sign_i, exponent_nxt, significand_nxt };
endmodule
