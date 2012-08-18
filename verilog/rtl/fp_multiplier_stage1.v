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
// First stage of floating point multiplier pipeline
// - Compute result exponent
// - Detect zero result
//

`include "instruction_format.h"

module fp_multiplier_stage1
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH,
	parameter SIGNIFICAND_PRODUCT_WIDTH = (SIGNIFICAND_WIDTH + 1) * 2)

	(input										clk,
	input [5:0]									operation_i,
	input [TOTAL_WIDTH - 1:0]					operand1_i,
	input [TOTAL_WIDTH - 1:0]					operand2_i,
	output reg[31:0]							mul1_muliplicand = 0,
	output reg[31:0]							mul1_multiplier = 0,
	output reg[EXPONENT_WIDTH - 1:0] 			mul1_exponent = 0,
	output reg									mul1_sign = 0);

	reg 										sign1 = 0;
	reg[EXPONENT_WIDTH - 1:0] 					exponent1 = 0;
	reg[EXPONENT_WIDTH - 1:0] 					result_exponent = 0;

	wire sign2 = operand2_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH];
	wire[EXPONENT_WIDTH - 1:0] exponent2 = operand2_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH - 1:SIGNIFICAND_WIDTH];
	wire result_sign = sign1 ^ sign2;

	// If the first parameter is an integer, treat it as a float now for
	// conversion.
	always @*
	begin
		if (operation_i == `OP_SITOF)	// SITOF conversion
		begin
			// Note: this is quick and dirty for now. I just truncate the input
			// if it is larger than the significand width.  A smarter approach
			// would detect the various widths and shift.
			sign1 = operand1_i[31];
			exponent1 = SIGNIFICAND_WIDTH + 8'h7f;
			if (sign1)
				mul1_muliplicand = (operand1_i ^ {32{1'b1}}) + 1;
			else
				mul1_muliplicand = operand1_i;
		end
		else
		begin
			sign1 = operand1_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH];
			exponent1 = operand1_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH - 1:SIGNIFICAND_WIDTH];
			mul1_muliplicand = { 1'b1, operand1_i[SIGNIFICAND_WIDTH - 1:0] };
		end
	end
	
	always @*
	begin
		// If we know the result will be zero, just set the second operand
		// to ensure the result will be zero.
		if (is_zero_nxt)
			mul1_multiplier = 0;
		else
			mul1_multiplier = { 1'b1, operand2_i[SIGNIFICAND_WIDTH - 1:0] };
	end
	
	// Unbias the exponents so we can add them
	wire[EXPONENT_WIDTH - 1:0] unbiased_exponent1 = { ~exponent1[EXPONENT_WIDTH - 1], 
			exponent1[EXPONENT_WIDTH - 2:0] };
	wire[EXPONENT_WIDTH - 1:0] unbiased_exponent2 = { ~exponent2[EXPONENT_WIDTH - 1], 
			exponent2[EXPONENT_WIDTH - 2:0] };

	// The result exponent is simply the sum of the two exponents
	wire[EXPONENT_WIDTH - 1:0] unbiased_result_exponent = unbiased_exponent1 + unbiased_exponent2;

	// Check for zero explicitly, since a leading 1 is otherwise 
	// assumed for the significand
	wire is_zero_nxt = operand1_i == 0 || operand2_i == 0;

	// Re-bias the result exponent.  Note that we subtract the significand width
	// here because of the multiplication.
	always @*
	begin
		if (is_zero_nxt)
			result_exponent = 0;
		else
			result_exponent = { ~unbiased_result_exponent[EXPONENT_WIDTH - 1], 
				unbiased_result_exponent[EXPONENT_WIDTH - 2:0] } + 1;
	end
	
	always @(posedge clk)
	begin
		mul1_exponent				<= #1 result_exponent;
		mul1_sign 					<= #1 result_sign;
	end
endmodule
