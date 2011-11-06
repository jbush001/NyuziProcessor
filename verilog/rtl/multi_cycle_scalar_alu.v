module multi_cycle_scalar_alu
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input								clk,
	input [5:0]							operation_i,
	input [TOTAL_WIDTH - 1:0]			operand1_i,
	input [TOTAL_WIDTH - 1:0]			operand2_i,
	output reg [TOTAL_WIDTH - 1:0]		result_o);

	wire[5:0] 							adder_operand_align_shift;
	wire[SIGNIFICAND_WIDTH + 2:0] 		adder_swapped_significand1;
	wire[SIGNIFICAND_WIDTH + 2:0] 		adder_swapped_significand2;
	wire[EXPONENT_WIDTH - 1:0] 			adder_exponent1;
	wire[EXPONENT_WIDTH - 1:0] 			adder_exponent2;
	wire 								adder_result_is_inf_stage1;
	wire 								adder_result_is_nan_stage1;
	wire[5:0] 							adder_stage2_operation;
	wire 								adder_exponent2_larger;


	wire[EXPONENT_WIDTH - 1:0] 			unnormalized_exponent_ff; 
	wire[SIGNIFICAND_WIDTH + 2:0] 		aligned1_ff;
	wire[SIGNIFICAND_WIDTH + 2:0] 		aligned2_ff;
	wire 								adder_result_is_inf_stage2;
	wire 								result_is_nan_stage2_ff;
	wire[5:0] 							stage3_operation;


	reg[SIGNIFICAND_WIDTH + 2:0] 		ones_complement_result;
	wire[SIGNIFICAND_WIDTH + 2:0] 		unnormalized_significand;	// Note: three extra bit for hidden bits and carry.
	integer 							bit_index;
	integer 							highest_bit;
	reg 								result_sign;
	reg[EXPONENT_WIDTH - 1:0] 			result_exponent;
	wire[SIGNIFICAND_WIDTH + 2:0] 		result_significand;
	wire 								addition;
	wire 								result_equal;
	wire 								result_negative;

	initial
	begin
		result_o = 0;
		ones_complement_result = 0;
		result_sign = 0;
		result_exponent = 0;
	end

	fp_adder_stage1 adder1(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i),
		.operand2_i(operand2_i),
		.operand_align_shift_o(adder_operand_align_shift),
		.swapped_significand1_o(adder_swapped_significand1),
		.swapped_significand2_o(adder_swapped_significand2),
		.exponent1_o(adder_exponent1),
		.exponent2_o(adder_exponent2),
		.result_is_inf_stage1_o(adder_result_is_inf_stage1),
		.result_is_nan_stage1_o(adder_result_is_nan_stage1),
		.operation_o(adder_stage2_operation),
		.exponent2_larger_o(adder_exponent2_larger));

	fp_adder_stage2 adder2(
		.clk(clk),
		.operation_i(adder_stage2_operation),
		.operand_align_shift_i(adder_operand_align_shift),
		.swapped_significand1_i(adder_swapped_significand1),
		.swapped_significand2_i(adder_swapped_significand2),
		.exponent1_i(adder_exponent1),
		.exponent2_i(adder_exponent2),
		.result_is_inf_stage1_i(adder_result_is_inf_stage1),
		.result_is_nan_stage1_i(adder_result_is_nan_stage1),
		.exponent2_larger_i(adder_exponent2_larger),
		.unnormalized_exponent_ff(unnormalized_exponent_ff),
		.aligned1_ff(aligned1_ff),
		.aligned2_ff(aligned2_ff),
		.adder_result_is_inf_stage2(adder_result_is_inf_stage2),
		.result_is_nan_stage2_ff(result_is_nan_stage2_ff),
		.operation_o(stage3_operation));


	/////////////////////////////////////////////////////////////
	// Stage 3 Adder
	/////////////////////////////////////////////////////////////

	// Add
	assign unnormalized_significand = aligned1_ff + aligned2_ff;

	// Convert back to ones complement
	always @*
	begin
		if (unnormalized_significand[SIGNIFICAND_WIDTH + 2])
		begin
			ones_complement_result = ~unnormalized_significand + 1;	
			result_sign = 1;
		end
		else
		begin
			ones_complement_result = unnormalized_significand;
			result_sign = 0;
		end
	end

	// Re-normalize	the result.
	// Find the highest set bit in the significand.  Infer a priority encoder.
	always @*
	begin
		highest_bit = 0;
		for (bit_index = 0; bit_index <= SIGNIFICAND_WIDTH + 2; bit_index = bit_index + 1)
		begin
			if (ones_complement_result[bit_index])
				highest_bit = bit_index;
		end
	end

	// Adjust the exponent
	always @*
	begin
		// Decrease the exponent by the number of shifted binary digits.
		if (highest_bit == 0)
			result_exponent = 0;
		else
			result_exponent = unnormalized_exponent_ff - (SIGNIFICAND_WIDTH - highest_bit);
	end

	// Shift the significand
	assign result_significand = ones_complement_result << (SIGNIFICAND_WIDTH + 3 - highest_bit);

	assign result_equal = result_exponent == 0 && result_significand[SIGNIFICAND_WIDTH + 2:3] == 0;
	assign result_negative = result_sign == 1;

	// Put the results back together, handling exceptional conditions
	always @*
	begin
		if (stage3_operation == 6'b100000 || stage3_operation == 6'b100001)
		begin
			// Is addition or subtraction.  Encode the result
			if (result_is_nan_stage2_ff)
				result_o = { 1'b0, {EXPONENT_WIDTH{1'b1}}, {SIGNIFICAND_WIDTH{1'b1}} };
			else if (adder_result_is_inf_stage2)
				result_o = { 1'b0, {EXPONENT_WIDTH{1'b1}}, {SIGNIFICAND_WIDTH{1'b0}} };	// inf
			else
				result_o = { result_sign, result_exponent, result_significand[SIGNIFICAND_WIDTH + 2:3] };
		end
		else
		begin
			// Comparison operation
			case (stage3_operation)
				6'b101100: result_o = !result_equal & !result_negative; // Greater than
				6'b101110: result_o = result_negative;   // Less than
				6'b101101: result_o = !result_negative;      // Greater than or equal
				6'b101111: result_o = result_equal || result_negative; // Less than or equal
				default: result_o = 0;
			endcase
		end
	end

endmodule
