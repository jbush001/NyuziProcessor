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

`include "defines.v"

module multi_stage_alu
	(input                clk,
	input                 reset,
	input [5:0]           ds_alu_op,
	input [31:0]          operand1,
	input [31:0]          operand2,
	output logic [31:0]     multi_stage_result);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic [`FP_EXPONENT_WIDTH-1:0] add1_exponent1;// From fp_adder_stage1 of fp_adder_stage1.v
	logic [`FP_EXPONENT_WIDTH-1:0] add1_exponent2;// From fp_adder_stage1 of fp_adder_stage1.v
	logic		add1_exponent2_larger;	// From fp_adder_stage1 of fp_adder_stage1.v
	logic [5:0]	add1_operand_align_shift;// From fp_adder_stage1 of fp_adder_stage1.v
	logic [`FP_SIGNIFICAND_WIDTH+2:0] add1_significand1;// From fp_adder_stage1 of fp_adder_stage1.v
	logic [`FP_SIGNIFICAND_WIDTH+2:0] add1_significand2;// From fp_adder_stage1 of fp_adder_stage1.v
	logic [`FP_EXPONENT_WIDTH-1:0] add2_exponent;// From add2 of fp_adder_stage2.v
	logic [`FP_SIGNIFICAND_WIDTH+2:0] add2_significand1;// From add2 of fp_adder_stage2.v
	logic [`FP_SIGNIFICAND_WIDTH+2:0] add2_significand2;// From add2 of fp_adder_stage2.v
	logic [`FP_EXPONENT_WIDTH-1:0] add3_exponent;// From add3 of fp_adder_stage3.v
	logic		add3_sign;		// From add3 of fp_adder_stage3.v
	logic [`FP_SIGNIFICAND_WIDTH+2:0] add3_significand;// From add3 of fp_adder_stage3.v
	logic [7:0]	mul1_exponent;		// From mul1 of fp_multiplier_stage1.v
	logic		mul1_sign;		// From mul1 of fp_multiplier_stage1.v
	logic		mul_overflow_stage2;	// From mul1 of fp_multiplier_stage1.v
	logic		mul_underflow_stage2;	// From mul1 of fp_multiplier_stage1.v
	// End of automatics

	logic[5:0] 								operation2;
	logic[5:0] 								operation3;
	logic[5:0] 								operation4;
	logic [`FP_EXPONENT_WIDTH - 1:0] 				mul2_exponent;
	logic 									mul2_sign;
	logic [`FP_EXPONENT_WIDTH - 1:0] 				mul3_exponent;
	logic 									mul3_sign;
	logic[(`FP_SIGNIFICAND_WIDTH + 1) * 2 - 1:0] 	mux_significand;
	logic[`FP_EXPONENT_WIDTH - 1:0] 				mux_exponent; 
	logic 									mux_sign;
	logic[`FP_EXPONENT_WIDTH - 1:0] 				norm_exponent;
	logic[`FP_SIGNIFICAND_WIDTH - 1:0] 			norm_significand;
	logic									norm_sign;
	logic[31:0]								multiplicand;
	logic[31:0]								multiplier;
	logic[47:0]								mult_product;
	logic[31:0]								mul1_muliplicand;
	logic[31:0]								mul1_multiplier;
	logic										mul_overflow_stage3;
	logic										mul_overflow_stage4;
	logic										mul_underflow_stage3;
	logic										mul_underflow_stage4;

	// Check for inf/nan
	wire op1_is_special = operand1[30:23] == {`FP_EXPONENT_WIDTH{1'b1}};
	wire op1_is_inf = op1_is_special && operand1[22:0] == 0;
	wire op1_is_nan = op1_is_special && operand1[22:0] != 0;
	wire op1_is_zero = operand1[30:0] == 0;
	wire op1_is_negative = operand1[31];
	wire op2_is_special = operand2[30:23] == {`FP_EXPONENT_WIDTH{1'b1}};
	wire op2_is_inf = op2_is_special && operand2[22:0] == 0;
	wire op2_is_nan = op2_is_special && operand2[22:0] != 0;
	wire op2_is_zero = operand2[30:0] == 0;
	wire op2_is_negative = operand2[31];
	logic result_is_nan_stage1;
	wire result_is_inf_stage1 = !result_is_nan_stage1 && (op1_is_inf || op2_is_inf);
	logic result_is_inf_stage2;
	logic result_is_nan_stage2;
	logic result_is_inf_stage3;
	logic result_is_nan_stage3;
	logic result_is_inf_stage4;
	logic result_is_nan_stage4;
	logic special_is_neg_stage1;
	logic special_is_neg_stage2;
	logic special_is_neg_stage3;
	logic special_is_neg_stage4;

	always_comb
	begin
		unique case (ds_alu_op)
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
					.add1_significand1(add1_significand1[`FP_SIGNIFICAND_WIDTH+2:0]),
					.add1_exponent1	(add1_exponent1[`FP_EXPONENT_WIDTH-1:0]),
					.add1_significand2(add1_significand2[`FP_SIGNIFICAND_WIDTH+2:0]),
					.add1_exponent2	(add1_exponent2[`FP_EXPONENT_WIDTH-1:0]),
					.add1_exponent2_larger(add1_exponent2_larger),
					// Inputs
					.clk		(clk),
					.reset		(reset),
					.ds_alu_op	(ds_alu_op[5:0]),
					.operand1	(operand1[31:0]),
					.operand2	(operand2[31:0]));
		
	fp_adder_stage2 add2(/*AUTOINST*/
			     // Outputs
			     .add2_exponent	(add2_exponent[`FP_EXPONENT_WIDTH-1:0]),
			     .add2_significand1	(add2_significand1[`FP_SIGNIFICAND_WIDTH+2:0]),
			     .add2_significand2	(add2_significand2[`FP_SIGNIFICAND_WIDTH+2:0]),
			     // Inputs
			     .clk		(clk),
			     .reset		(reset),
			     .add1_operand_align_shift(add1_operand_align_shift[5:0]),
			     .add1_significand1	(add1_significand1[`FP_SIGNIFICAND_WIDTH+2:0]),
			     .add1_significand2	(add1_significand2[`FP_SIGNIFICAND_WIDTH+2:0]),
			     .add1_exponent1	(add1_exponent1[`FP_EXPONENT_WIDTH-1:0]),
			     .add1_exponent2	(add1_exponent2[`FP_EXPONENT_WIDTH-1:0]),
			     .add1_exponent2_larger(add1_exponent2_larger));

	fp_adder_stage3 add3(/*AUTOINST*/
			     // Outputs
			     .add3_significand	(add3_significand[`FP_SIGNIFICAND_WIDTH+2:0]),
			     .add3_sign		(add3_sign),
			     .add3_exponent	(add3_exponent[`FP_EXPONENT_WIDTH-1:0]),
			     // Inputs
			     .clk		(clk),
			     .reset		(reset),
			     .add2_significand1	(add2_significand1[`FP_SIGNIFICAND_WIDTH+2:0]),
			     .add2_significand2	(add2_significand2[`FP_SIGNIFICAND_WIDTH+2:0]),
			     .add2_exponent	(add2_exponent[`FP_EXPONENT_WIDTH-1:0]));

	fp_multiplier_stage1 mul1(/*AUTOINST*/
				  // Outputs
				  .mul1_muliplicand	(mul1_muliplicand[31:0]),
				  .mul1_multiplier	(mul1_multiplier[31:0]),
				  .mul1_exponent	(mul1_exponent[7:0]),
				  .mul1_sign		(mul1_sign),
				  .mul_overflow_stage2	(mul_overflow_stage2),
				  .mul_underflow_stage2	(mul_underflow_stage2),
				  // Inputs
				  .clk			(clk),
				  .reset		(reset),
				  .ds_alu_op		(ds_alu_op[5:0]),
				  .operand1		(operand1[31:0]),
				  .operand2		(operand2[31:0]));

	// Mux results into the multiplier, which is used both for integer
	// and floating point multiplication.
	always_comb
	begin
		if (ds_alu_op == `OP_IMUL)
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
	always_comb
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
			mux_significand = { add3_significand, {`FP_SIGNIFICAND_WIDTH{1'b0}} };
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
	always_comb
	begin
		unique case (operation4)
			`OP_ITOF: multi_stage_result = { norm_sign, norm_exponent, norm_significand };
			`OP_IMUL: multi_stage_result = mult_product[31:0];	// Truncate product

			// Note: floating point comparisions return false if the comparison
			// is unordered (either operand is NaN).
			`OP_FGTR: 
			begin
				if (result_is_nan_stage4)
					multi_stage_result = 0;
				else
					multi_stage_result = !result_equal & !result_negative;
			end
			
			`OP_FLT:
			begin
				if (result_is_nan_stage4)
					multi_stage_result = 0;
				else
					multi_stage_result = result_negative;
			end

			`OP_FGTE:
			begin
				if (result_is_nan_stage4)
					multi_stage_result = 0;
				else
					multi_stage_result = !result_negative;
			end

			`OP_FLTE:
			begin
				if (result_is_nan_stage4)
					multi_stage_result = 0;
				else
					multi_stage_result = result_equal || result_negative;
			end

			default:
			begin
				// Not a comparison, take the result as is.
				if (operation4 == `OP_FMUL && mul_underflow_stage4)
					multi_stage_result = { norm_sign, 31'd0 };	// zero
				else if ((operation4 == `OP_FMUL && mul_overflow_stage4) || result_is_inf_stage4)
					multi_stage_result = { special_is_neg_stage4, {`FP_EXPONENT_WIDTH{1'b1}}, {`FP_SIGNIFICAND_WIDTH{1'b0}} };	// inf
				else if (result_is_nan_stage4)
					multi_stage_result = { 1'b0, {`FP_EXPONENT_WIDTH{1'b1}}, 1'b1, {`FP_SIGNIFICAND_WIDTH - 1{1'b0}}  }; // quiet NaN
				else
					multi_stage_result = { norm_sign, norm_exponent, norm_significand };
			end
		endcase
	end
	
	// Internal flops for the first three stages.
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			mul2_exponent <= {(1+(`FP_EXPONENT_WIDTH-1)){1'b0}};
			mul2_sign <= 1'h0;
			mul3_exponent <= {(1+(`FP_EXPONENT_WIDTH-1)){1'b0}};
			mul3_sign <= 1'h0;
			mul_overflow_stage3 <= 1'h0;
			mul_overflow_stage4 <= 1'h0;
			mul_underflow_stage3 <= 1'h0;
			mul_underflow_stage4 <= 1'h0;
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
			operation2 <= ds_alu_op;
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
			mul_underflow_stage3 <= mul_underflow_stage2;
			mul_underflow_stage4 <= mul_underflow_stage3;
		end
	end
endmodule
