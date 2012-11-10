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
// FP reciprocal stage 1
// - Compute estimate for reciprocal using lookup table
//

module fp_recip_stage1
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input								clk,
	input [SIGNIFICAND_WIDTH - 1:0]		significand_i,
	input [EXPONENT_WIDTH - 1:0]		exponent_i,
	input								sign_i,
	output reg[SIGNIFICAND_WIDTH - 1:0]	significand_o = 0,
	output reg[EXPONENT_WIDTH - 1:0]	exponent_o = 0,
	output reg							sign_o = 0);

	localparam 							LUT_WIDTH = 6;

	wire[LUT_WIDTH - 1:0]				lut_result;
	reg[SIGNIFICAND_WIDTH - 1:0]		significand_nxt = 0;
	reg[EXPONENT_WIDTH - 1:0]			exponent_nxt = 0;

	reciprocal_rom rom(
		.addr_i(significand_i[22:(22 - LUT_WIDTH + 1)]),
		.data_o(lut_result));

	always @*
	begin
		if (significand_i == 0)
		begin
			// This would exceed the size of the output in the ROM table, since
			// this is the only entry with an extra bit.  Treat that special here.
			significand_nxt = { 1'b1, {SIGNIFICAND_WIDTH - 1{1'b0}} };
			exponent_nxt = 8'd254 - exponent_i + 1;
		end
		else
		begin
			// Add the leading one explicitly.
			significand_nxt = { 1'b1, lut_result, {SIGNIFICAND_WIDTH - LUT_WIDTH - 1{1'b0}} };
			exponent_nxt = 8'd254 - exponent_i;
		end
	end

	always @(posedge clk)
	begin
		significand_o 		<= #1 significand_nxt;
		exponent_o 			<= #1 exponent_nxt;
		sign_o				<= #1 sign_i;
	end
endmodule
