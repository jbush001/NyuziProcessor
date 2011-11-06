module multi_cycle_scalar_alu
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input								clk,
	input [5:0]							operation_i,
	input [TOTAL_WIDTH - 1:0]			operand1_i,
	input [TOTAL_WIDTH - 1:0]			operand2_i,
	output reg [TOTAL_WIDTH - 1:0]		result_o);

	wire[5:0] 							add1_operand_align_shift;
	wire[SIGNIFICAND_WIDTH + 2:0] 		add1_swapped_significand1;
	wire[SIGNIFICAND_WIDTH + 2:0] 		add1_swapped_significand2;
	wire[EXPONENT_WIDTH - 1:0] 			add1_exponent1;
	wire[EXPONENT_WIDTH - 1:0] 			add1_exponent2;
	wire 								add1_result_is_inf;
	wire 								add1_result_is_nan;
	wire[5:0] 							add1_operation;
	wire 								add1_exponent2_larger;
	wire[EXPONENT_WIDTH - 1:0] 			add2_unnormalized_exponent; 
	wire[SIGNIFICAND_WIDTH + 2:0] 		add2_aligned1;
	wire[SIGNIFICAND_WIDTH + 2:0] 		add2_aligned2;
	wire 								add2_result_is_inf;
	wire 								add2_result_is_nan;
	wire[5:0] 							add2_operation;


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

	fp_adder_stage1 add1(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i),
		.operand2_i(operand2_i),
		.operand_align_shift_o(add1_operand_align_shift),
		.swapped_significand1_o(add1_swapped_significand1),
		.swapped_significand2_o(add1_swapped_significand2),
		.exponent1_o(add1_exponent1),
		.exponent2_o(add1_exponent2),
		.result_is_inf_stage1_o(add1_result_is_inf),
		.result_is_nan_stage1_o(add1_result_is_nan),
		.operation_o(add1_operation),
		.exponent2_larger_o(add1_exponent2_larger));

	fp_adder_stage2 add2(
		.clk(clk),
		.operation_i(add1_operation),
		.operand_align_shift_i(add1_operand_align_shift),
		.swapped_significand1_i(add1_swapped_significand1),
		.swapped_significand2_i(add1_swapped_significand2),
		.exponent1_i(add1_exponent1),
		.exponent2_i(add1_exponent2),
		.result_is_inf_i(add1_result_is_inf),
		.result_is_nan_i(add1_result_is_nan),
		.exponent2_larger_i(add1_exponent2_larger),
		.unnormalized_exponent_o(add2_unnormalized_exponent),
		.aligned1_o(add2_aligned1),
		.aligned2_o(add2_aligned2),
		.result_is_inf_o(add2_result_is_inf),
		.result_is_nan_o(add2_result_is_nan),
		.operation_o(add2_operation));


	/////////////////////////////////////////////////////////////
	// Stage 3 Adder
	/////////////////////////////////////////////////////////////

	// Add
	assign unnormalized_significand = add2_aligned1 + add2_aligned2;

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
			result_exponent = add2_unnormalized_exponent - (SIGNIFICAND_WIDTH - highest_bit);
	end

	// Shift the significand
	assign result_significand = ones_complement_result << (SIGNIFICAND_WIDTH + 3 - highest_bit);

	assign result_equal = result_exponent == 0 && result_significand[SIGNIFICAND_WIDTH + 2:3] == 0;
	assign result_negative = result_sign == 1;

	// Put the results back together, handling exceptional conditions
	always @*
	begin
		if (add2_operation == 6'b100000 || add2_operation == 6'b100001)
		begin
			// Is addition or subtraction.  Encode the result
			if (add2_result_is_nan)
				result_o = { 1'b0, {EXPONENT_WIDTH{1'b1}}, {SIGNIFICAND_WIDTH{1'b1}} };
			else if (add2_result_is_inf)
				result_o = { 1'b0, {EXPONENT_WIDTH{1'b1}}, {SIGNIFICAND_WIDTH{1'b0}} };	// inf
			else
				result_o = { result_sign, result_exponent, result_significand[SIGNIFICAND_WIDTH + 2:3] };
		end
		else
		begin
			// Comparison operation
			case (add2_operation)
				6'b101100: result_o = !result_equal & !result_negative; // Greater than
				6'b101110: result_o = result_negative;   // Less than
				6'b101101: result_o = !result_negative;      // Greater than or equal
				6'b101111: result_o = result_equal || result_negative; // Less than or equal
				default: result_o = 0;
			endcase
		end
	end

endmodule
