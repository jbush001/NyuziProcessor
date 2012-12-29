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
// Handles arithmetic operations that take more than one cycle to complete.
// This includes many floating point operations and integer multiplies.
// This module has 3 cycles of latency, but the output from the last stage is not 
// registered here (it's expected to be muxed and registered in the execute stage).
// The total latency for these operations is then 4 cycles, but one instruction can 
// be issued/completed per cycle.   
//

`include "instruction_format.h"

module multi_cycle_scalar_alu
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter SFP_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input									clk,
	input									reset,
	input [5:0]								operation_i,
	input [SFP_WIDTH - 1:0]					operand1,
	input [SFP_WIDTH - 1:0]					operand2,
	output reg [SFP_WIDTH - 1:0]			multi_cycle_result);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [EXPONENT_WIDTH-1:0] add1_exponent1;// From fp_adder_stage1 of fp_adder_stage1.v
	wire [EXPONENT_WIDTH-1:0] add1_exponent2;// From fp_adder_stage1 of fp_adder_stage1.v
	wire		add1_exponent2_larger;	// From fp_adder_stage1 of fp_adder_stage1.v
	wire [5:0]	add1_operand_align_shift;// From fp_adder_stage1 of fp_adder_stage1.v
	wire [SIGNIFICAND_WIDTH+2:0] add1_significand1;// From fp_adder_stage1 of fp_adder_stage1.v
	wire [SIGNIFICAND_WIDTH+2:0] add1_significand2;// From fp_adder_stage1 of fp_adder_stage1.v
	wire [EXPONENT_WIDTH-1:0] add2_exponent;// From add2 of fp_adder_stage2.v
	wire [SIGNIFICAND_WIDTH+2:0] add2_significand1;// From add2 of fp_adder_stage2.v
	wire [SIGNIFICAND_WIDTH+2:0] add2_significand2;// From add2 of fp_adder_stage2.v
	wire [EXPONENT_WIDTH-1:0] add3_exponent;// From add3 of fp_adder_stage3.v
	wire		add3_sign;		// From add3 of fp_adder_stage3.v
	wire [SIGNIFICAND_WIDTH+2:0] add3_significand;// From add3 of fp_adder_stage3.v
	wire [7:0]	mul1_exponent;		// From mul1 of fp_multiplier_stage1.v
	wire		mul1_sign;		// From mul1 of fp_multiplier_stage1.v
	wire		mul_overflow_stage2;	// From mul1 of fp_multiplier_stage1.v
	// End of automatics

	reg[5:0] 								operation2;
	reg[5:0] 								operation3;
	reg[5:0] 								operation4;
	reg [EXPONENT_WIDTH - 1:0] 				mul2_exponent;
	reg 									mul2_sign;
	reg [EXPONENT_WIDTH - 1:0] 				mul3_exponent;
	reg 									mul3_sign;
	reg[(SIGNIFICAND_WIDTH + 1) * 2 - 1:0] 	mux_significand;
	reg[EXPONENT_WIDTH - 1:0] 				mux_exponent; 
	reg 									mux_sign;
	wire[EXPONENT_WIDTH - 1:0] 				norm_exponent;
	wire[SIGNIFICAND_WIDTH - 1:0] 			norm_significand;
	wire									norm_sign;
	reg[31:0]								multiplicand;
	reg[31:0]								multiplier;
	wire[47:0]								mult_product;
	wire[31:0]								mul1_muliplicand;
	wire[31:0]								mul1_multiplier;
	reg										mul_overflow_stage3;
	reg										mul_overflow_stage4;

	// Check for inf/nan
	wire op1_is_special = operand1[30:23] == {EXPONENT_WIDTH{1'b1}};
	wire op1_is_inf = op1_is_special && operand1[22:0] == 0;
	wire op1_is_nan = op1_is_special && operand1[22:0] != 0;
	wire op1_is_zero = operand1[30:0] == 0;
	wire op1_is_negative = operand1[31];
	wire op2_is_special = operand2[30:23] == {EXPONENT_WIDTH{1'b1}};
	wire op2_is_inf = op2_is_special && operand2[22:0] == 0;
	wire op2_is_nan = op2_is_special && operand2[22:0] != 0;
	wire op2_is_zero = operand2[30:0] == 0;
	wire op2_is_negative = operand2[31];
	reg result_is_nan_stage1;
	wire result_is_inf_stage1 = !result_is_nan_stage1 && (op1_is_inf || op2_is_inf);
	reg result_is_inf_stage2;
	reg result_is_nan_stage2;
	reg result_is_inf_stage3;
	reg result_is_nan_stage3;
	reg result_is_inf_stage4;
	reg result_is_nan_stage4;
	reg special_is_neg_stage1;
	reg special_is_neg_stage2;
	reg special_is_neg_stage3;
	reg special_is_neg_stage4;

	always @*
	begin
		case (operation_i)
			`OP_FADD:
			begin
				result_is_nan_stage1 = op1_is_nan || op2_is_nan
					|| (op1_is_inf && op2_is_inf && op1_is_negative != op2_is_negative);
				
				// Only set for INF
				special_is_neg_stage1 = op1_is_inf ? op1_is_negative : op2_is_negative;
			end

			`OP_FMUL:
			begin
				result_is_nan_stage1 = op1_is_nan || op2_is_nan
					|| (op1_is_inf && op2_is_zero)
					|| (op1_is_zero && op2_is_inf);

				// Only set for INF
				special_is_neg_stage1 = op1_is_negative ^ op2_is_negative;
			end

			default:	// FSUB, comparisons, or don't care
			begin
				result_is_nan_stage1 = (op1_is_inf && op2_is_inf 
					&& op1_is_negative == op2_is_negative)
					|| op1_is_nan || op2_is_nan;

				// Only set for INF
				special_is_neg_stage1 = op1_is_inf ? op1_is_negative : !op2_is_negative;
			end
		endcase
	end

	fp_adder_stage1 fp_adder_stage1(/*AUTOINST*/
					// Outputs
					.add1_operand_align_shift(add1_operand_align_shift[5:0]),
					.add1_significand1(add1_significand1[SIGNIFICAND_WIDTH+2:0]),
					.add1_exponent1	(add1_exponent1[EXPONENT_WIDTH-1:0]),
					.add1_significand2(add1_significand2[SIGNIFICAND_WIDTH+2:0]),
					.add1_exponent2	(add1_exponent2[EXPONENT_WIDTH-1:0]),
					.add1_exponent2_larger(add1_exponent2_larger),
					// Inputs
					.clk		(clk),
					.reset		(reset),
					.operation_i	(operation_i[5:0]),
					.operand1	(operand1[SFP_WIDTH-1:0]),
					.operand2	(operand2[SFP_WIDTH-1:0]));
		
	fp_adder_stage2 add2(/*AUTOINST*/
			     // Outputs
			     .add2_exponent	(add2_exponent[EXPONENT_WIDTH-1:0]),
			     .add2_significand1	(add2_significand1[SIGNIFICAND_WIDTH+2:0]),
			     .add2_significand2	(add2_significand2[SIGNIFICAND_WIDTH+2:0]),
			     // Inputs
			     .clk		(clk),
			     .reset		(reset),
			     .add1_operand_align_shift(add1_operand_align_shift[5:0]),
			     .add1_significand1	(add1_significand1[SIGNIFICAND_WIDTH+2:0]),
			     .add1_significand2	(add1_significand2[SIGNIFICAND_WIDTH+2:0]),
			     .add1_exponent1	(add1_exponent1[EXPONENT_WIDTH-1:0]),
			     .add1_exponent2	(add1_exponent2[EXPONENT_WIDTH-1:0]),
			     .add1_exponent2_larger(add1_exponent2_larger));

	fp_adder_stage3 add3(/*AUTOINST*/
			     // Outputs
			     .add3_significand	(add3_significand[SIGNIFICAND_WIDTH+2:0]),
			     .add3_sign		(add3_sign),
			     .add3_exponent	(add3_exponent[EXPONENT_WIDTH-1:0]),
			     // Inputs
			     .clk		(clk),
			     .reset		(reset),
			     .add2_significand1	(add2_significand1[SIGNIFICAND_WIDTH+2:0]),
			     .add2_significand2	(add2_significand2[SIGNIFICAND_WIDTH+2:0]),
			     .add2_exponent	(add2_exponent[EXPONENT_WIDTH-1:0]));

	fp_multiplier_stage1 mul1(/*AUTOINST*/
				  // Outputs
				  .mul1_muliplicand	(mul1_muliplicand[31:0]),
				  .mul1_multiplier	(mul1_multiplier[31:0]),
				  .mul1_exponent	(mul1_exponent[7:0]),
				  .mul1_sign		(mul1_sign),
				  .mul_overflow_stage2	(mul_overflow_stage2),
				  // Inputs
				  .clk			(clk),
				  .reset		(reset),
				  .operation_i		(operation_i[5:0]),
				  .operand1		(operand1[SFP_WIDTH-1:0]),
				  .operand2		(operand2[SFP_WIDTH-1:0]));

	// Mux results into the multiplier, which is used both for integer
	// and floating point multiplication.
	always @*
	begin
		if (operation_i == `OP_IMUL)
		begin
			// Integer multiply
			multiplicand = operand1;
			multiplier = operand2;
		end
		else
		begin
			// Floating point multiply
			multiplicand = mul1_muliplicand;
			multiplier = mul1_multiplier;
		end
	
	end

	integer_multiplier imul(
		/*AUTOINST*/
				// Outputs
				.mult_product	(mult_product[47:0]),
				// Inputs
				.clk		(clk),
				.reset		(reset),
				.multiplicand	(multiplicand[31:0]),
				.multiplier	(multiplier[31:0]));

	// Select the appropriate result (either multiplication or addition) to feed into 
	// the shared normalization stage
	always @*
	begin
		if (operation4 == `OP_FMUL || operation4 == `OP_ITOF)
		begin
			// Selection multiplication result
			mux_significand = mult_product;
			mux_exponent = mul3_exponent;
			mux_sign = mul3_sign;
		end
		else
		begin
			// Select adder pipeline result
			// XXX mux_significand is 48 bits, but rhs is 49 bits
			// - need an extra bit for overflow
			mux_significand = { add3_significand, {SIGNIFICAND_WIDTH{1'b0}} };
			mux_exponent = add3_exponent;
			mux_sign = add3_sign;
		end
	end

	fp_normalize norm(
		.significand_i(mux_significand),
		.exponent_i(mux_exponent),
		.significand_o(norm_significand),
		.exponent_o(norm_exponent),
		.sign_i(mux_sign),
		.sign_o(norm_sign));
		
	wire result_equal = norm_exponent == 0 && norm_significand == 0;
	wire result_negative = norm_sign == 1;

	// Output multiplexer
	always @*
	begin
		case (operation4)
			`OP_ITOF: multi_cycle_result = { norm_sign, norm_exponent, norm_significand };
			`OP_IMUL: multi_cycle_result = mult_product[31:0];	// Truncate product
			`OP_FGTR: 
			begin
				if (result_is_nan_stage4)
					multi_cycle_result = 0;
				else
					multi_cycle_result = !result_equal & !result_negative;
			end
			
			`OP_FLT:
			begin
				if (result_is_nan_stage4)
					multi_cycle_result = 0;
				else
					multi_cycle_result = result_negative;
			end

			`OP_FGTE:
			begin
				if (result_is_nan_stage4)
					multi_cycle_result = 0;
				else
					multi_cycle_result = !result_negative;
			end

			`OP_FLTE:
			begin
				if (result_is_nan_stage4)
					multi_cycle_result = 0;
				else
					multi_cycle_result = result_equal || result_negative;
			end

			default:
			begin
				// Not a comparison, take the result as is.
				if ((operation4 == `OP_FMUL && mul_overflow_stage4) || result_is_inf_stage4)
					multi_cycle_result = { special_is_neg_stage4, {EXPONENT_WIDTH{1'b1}}, {SIGNIFICAND_WIDTH{1'b0}} };	// inf
				else if (result_is_nan_stage4)
					multi_cycle_result = { 1'b0, {EXPONENT_WIDTH{1'b1}}, 1'b1, {SIGNIFICAND_WIDTH - 1{1'b0}}  }; // quiet NaN
				else
					multi_cycle_result = { norm_sign, norm_exponent, norm_significand };
			end
		endcase
	end
	
	// Internal flops for the first three stages.
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			mul2_exponent <= {EXPONENT_WIDTH{1'b0}};
			mul2_sign <= 1'h0;
			mul3_exponent <= {EXPONENT_WIDTH{1'b0}};
			mul3_sign <= 1'h0;
			mul_overflow_stage3 <= 1'h0;
			mul_overflow_stage4 <= 1'h0;
			operation2 <= 6'h0;
			operation3 <= 6'h0;
			operation4 <= 6'h0;
			result_is_inf_stage2 <= 1'h0;
			result_is_inf_stage3 <= 1'h0;
			result_is_inf_stage4 <= 1'h0;
			result_is_nan_stage2 <= 1'h0;
			result_is_nan_stage3 <= 1'h0;
			result_is_nan_stage4 <= 1'h0;
			special_is_neg_stage2 <= 1'h0;
			special_is_neg_stage3 <= 1'h0;
			special_is_neg_stage4 <= 1'h0;
			// End of automatics
		end
		else
		begin
			mul2_exponent <= mul1_exponent;
			mul2_sign <= mul1_sign;
			mul3_exponent <= mul2_exponent;
			mul3_sign <= mul2_sign;
			operation2 <= operation_i;
			operation3 <= operation2;
			operation4 <= operation3;
			result_is_inf_stage2 <= result_is_inf_stage1;
			result_is_nan_stage2 <= result_is_nan_stage1;
			result_is_inf_stage3 <= result_is_inf_stage2;
			result_is_nan_stage3 <= result_is_nan_stage2;
			result_is_inf_stage4 <= result_is_inf_stage3;
			result_is_nan_stage4 <= result_is_nan_stage3;
			special_is_neg_stage2 <= special_is_neg_stage1;
			special_is_neg_stage3 <= special_is_neg_stage2;
			special_is_neg_stage4 <= special_is_neg_stage3;
			mul_overflow_stage3 <= mul_overflow_stage2;
			mul_overflow_stage4 <= mul_overflow_stage3;
		end
	end
endmodule
