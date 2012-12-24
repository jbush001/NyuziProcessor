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

`include "instruction_format.h"

//
// First stage of floating point multiplier pipeline
// - Compute result exponent
// - Insert hidden bits
//

module fp_multiplier_stage1
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter SFP_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH,
	parameter SIGNIFICAND_PRODUCT_WIDTH = (SIGNIFICAND_WIDTH + 1) * 2)

	(input										clk,
	input										reset,
	input [5:0]									operation_i,
	input [SFP_WIDTH - 1:0]					operand1,
	input [SFP_WIDTH - 1:0]					operand2,
	output reg[31:0]							mul1_muliplicand,
	output reg[31:0]							mul1_multiplier,
	output reg[7:0] 							mul1_exponent,
	output reg									mul1_sign,
	output reg									mul_overflow_stage2);

	reg sign1;
	reg[7:0] exponent1;
	reg sign2;
	reg[7:0] exponent2;

	// Multiplicand
	always @*
	begin
		if (operation_i == `OP_ITOF)
		begin
			// Dummy multiply by 1.0
			sign1 = 0;
			exponent1 = 127;
			mul1_muliplicand = { 32'h00800000 };
		end
		else
		begin
			sign1 = operand1[31];
			exponent1 = operand1[30:23];
			mul1_muliplicand = { 8'd0, exponent1 != 0, operand1[22:0] };
		end
	end
	
	always @*
	begin
		if (operation_i == `OP_ITOF)
		begin
			// Convert to unnormalized float for multiplication
			sign2 = operand2[31];
			exponent2 = 127 + 23;
			if (sign2)
				mul1_multiplier = (operand2 ^ {32{1'b1}}) + 1;
			else
				mul1_multiplier = operand2;
		end
		else
		begin
			sign2 = operand2[31];
			exponent2 = operand2[30:23];
			mul1_multiplier = { exponent2 != 0, operand2[22:0] };
		end
	end

	wire result_sign = sign1 ^ sign2;

	// Unbias the exponents so we can add them in two's complement.
	wire[7:0] unbiased_exponent1 = { ~exponent1[7], exponent1[6:0] } + 1;
	wire[7:0] unbiased_exponent2 = { ~exponent2[7], exponent2[6:0] } + 1;

	// The result exponent is simply the sum of the two exponents.
	wire[7:0] unbiased_result_exponent = unbiased_exponent1 + unbiased_exponent2;

	wire exponent_overflow = unbiased_exponent1[7] == unbiased_exponent2[7]
		&& unbiased_result_exponent[7] != unbiased_exponent1[7]
		&& exponent1 != 0 && exponent2 != 0; // Ignore subnormal numbers for now...

	// Re-bias the result exponent.
	wire[7:0] result_exponent = { ~unbiased_result_exponent[7], 
		unbiased_result_exponent[6:0] } - 1;
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			mul1_exponent <= 8'h0;
			mul1_sign <= 1'h0;
			mul_overflow_stage2 <= 1'h0;
			// End of automatics
		end
		else
		begin
			mul1_exponent <= result_exponent;
			mul1_sign <= result_sign;
			mul_overflow_stage2 <= exponent_overflow;
		end
	end
endmodule
