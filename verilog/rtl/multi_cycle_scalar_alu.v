module multi_cycle_scalar_alu
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input								clk,
	input [5:0]							operation_i,
	input [TOTAL_WIDTH - 1:0]			operand1_i,
	input [TOTAL_WIDTH - 1:0]			operand2_i,
	output reg [TOTAL_WIDTH - 1:0]		result_o);

	wire 								sign1;
	wire[EXPONENT_WIDTH - 1:0] 			exponent1;
	wire[SIGNIFICAND_WIDTH - 1:0] 		significand1;
	reg 								is_nan1;
	reg 								is_inf1;
	wire 								is_zero1;
	wire 								sign2;
	wire[EXPONENT_WIDTH - 1:0] 			exponent2;
	wire[SIGNIFICAND_WIDTH - 1:0] 		significand2;
	wire[EXPONENT_WIDTH:0] 				exponent_difference;	// Note extra carry bit
	reg[5:0] 							operand_align_shift_nxt;
	reg[5:0] 							operand_align_shift_ff;
	wire 								exponent2_larger;
	reg[EXPONENT_WIDTH - 1:0] 			exponent1_ff;
	reg[EXPONENT_WIDTH - 1:0] 			exponent2_ff;
	reg[SIGNIFICAND_WIDTH + 2:0] 		twos_complement_significand1;
	reg[SIGNIFICAND_WIDTH + 2:0] 		twos_complement_significand2;
	reg[SIGNIFICAND_WIDTH + 2:0] 		swapped_significand1_ff;
	reg[SIGNIFICAND_WIDTH + 2:0] 		swapped_significand2_ff;
	reg[SIGNIFICAND_WIDTH + 2:0] 		swapped_significand1_nxt;
	reg[SIGNIFICAND_WIDTH + 2:0] 		swapped_significand2_nxt;
	reg[SIGNIFICAND_WIDTH + 2:0] 		ones_complement_result;
	reg 								is_nan2;
	reg 								is_inf2;
	wire 								is_zero2;
	reg[SIGNIFICAND_WIDTH + 2:0] 		aligned1_ff;
	wire[SIGNIFICAND_WIDTH + 2:0] 		aligned2_nxt;
	reg[SIGNIFICAND_WIDTH + 2:0] 		aligned2_ff;
	reg[EXPONENT_WIDTH - 1:0] 			unnormalized_exponent_ff; 
	reg[EXPONENT_WIDTH - 1:0] 			unnormalized_exponent_nxt; 
	wire[SIGNIFICAND_WIDTH + 2:0] 		unnormalized_significand;	// Note: three extra bit for hidden bits and carry.
	integer 							bit_index;
	integer 							highest_bit;
	reg 								result_sign;
	reg[EXPONENT_WIDTH - 1:0] 			result_exponent;
	wire[SIGNIFICAND_WIDTH + 2:0] 		result_significand;
	reg 								result_is_inf_stage1_nxt;
	reg 								result_is_inf_stage1_ff;
	reg 								result_is_inf_stage2_ff;
	reg 								result_is_nan_stage1_nxt;
	reg 								result_is_nan_stage1_ff;
	reg 								result_is_nan_stage2_ff;
	wire 								subtract;
	reg[5:0] 							stage2_operation;
	reg[5:0] 							stage3_operation;
	wire 								result_equal;
	wire 								result_negative;
	reg 								exponent2_larger_ff;

	// Pull out fields from inputs
	assign sign1 = operand1_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH];
	assign exponent1 = operand1_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH - 1:SIGNIFICAND_WIDTH];
	assign significand1 = operand1_i[SIGNIFICAND_WIDTH - 1:0];
	assign sign2 = operand2_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH];
	assign exponent2 = operand2_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH - 1:SIGNIFICAND_WIDTH];
	assign significand2 = operand2_i[SIGNIFICAND_WIDTH - 1:0];

	initial
	begin
		result_o = 0;
		is_nan1 = 0;
		is_inf1 = 0;
		operand_align_shift_nxt = 0;
		operand_align_shift_ff = 0;
		exponent1_ff = 0;
		exponent2_ff = 0;
		twos_complement_significand1 = 0;
		twos_complement_significand2 = 0;
		swapped_significand1_ff = 0;
		swapped_significand2_ff = 0;
		swapped_significand1_nxt = 0;
		swapped_significand2_nxt = 0;
		ones_complement_result = 0;
		is_nan2 = 0;
		is_inf2 = 0;
		aligned1_ff = 0;
		aligned2_ff = 0;
		unnormalized_exponent_ff = 0;
		unnormalized_exponent_nxt = 0;
		result_sign = 0;
		result_exponent = 0;
		result_is_inf_stage1_nxt = 0;
		result_is_inf_stage1_ff = 0;
		result_is_inf_stage2_ff = 0;
		result_is_nan_stage1_nxt = 0;
		result_is_nan_stage1_ff = 0;
		result_is_nan_stage2_ff = 0;
		stage2_operation = 0;
		stage3_operation = 0;
		exponent2_larger_ff = 0;
	end

	/////////////////////////////////////////////////////////////
	// Stage 1 Adder
	/////////////////////////////////////////////////////////////

	// Compute exponent difference
	assign exponent_difference = exponent1 - exponent2;
	assign exponent2_larger = exponent_difference[EXPONENT_WIDTH];

	// Take absolute value of the exponent difference to compute the shift amount
	always @*
	begin
		if (exponent2_larger)
			operand_align_shift_nxt = ~exponent_difference + 1;
		else
			operand_align_shift_nxt = exponent_difference;
	end

	// Special case zero handling (there is no implicit leading 1 in this case)
	assign is_zero1 = exponent1 == 0;
	assign is_zero2 = exponent2 == 0;

	assign subtract = operation_i == 6'b100001;

	// Convert to 2s complement
	always @*
	begin
		if (sign1)
			twos_complement_significand1 = ~{ 2'b00, ~is_zero1, significand1 } + 1;
		else
			twos_complement_significand1 = { 2'b00, ~is_zero1, significand1 };

		if (sign2 ^ subtract)
			twos_complement_significand2 = ~{ 2'b00, ~is_zero2, significand2 } + 1;
		else
			twos_complement_significand2 = { 2'b00, ~is_zero2, significand2 };
	end

	// Swap
	always @*
	begin
		if (exponent2_larger)
		begin
			swapped_significand1_nxt = twos_complement_significand2;
			swapped_significand2_nxt = twos_complement_significand1;
		end
		else
		begin
			swapped_significand1_nxt = twos_complement_significand1;
			swapped_significand2_nxt = twos_complement_significand2;
		end
	end

	// Determine if any of the operands are inf or nan
	always @*
	begin
		if (exponent1 == {EXPONENT_WIDTH{1'b1}})
		begin
			is_inf1 = significand1 == 0;
			is_nan1 = ~is_inf1;
		end
		else
		begin
			is_inf1 = 0;
			is_nan1 = 0;
		end

		if (exponent2 == {EXPONENT_WIDTH{1'b1}})
		begin
			is_inf2 = significand2 == 0;
			is_nan2 = ~is_inf2;
		end
		else
		begin
			is_inf2 = 0;
			is_nan2 = 0;
		end
	end

	always @*
	begin
		if (is_inf1 || is_inf2)
		begin
			if (sign1 != sign2 && is_inf1 && is_inf2)
			begin
				// inf - inf = nan
				result_is_nan_stage1_nxt = 1;
				result_is_inf_stage1_nxt = 0;
			end
			else			
			begin
				// inf +/- anything = inf
				result_is_nan_stage1_nxt = 0;
				result_is_inf_stage1_nxt = 1;
			end
		end
		else if (is_nan1 || is_nan2)
		begin
			// nan +/- anything = nan
			result_is_nan_stage1_nxt = 1;
			result_is_inf_stage1_nxt = 0;
		end
		else
		begin
			result_is_nan_stage1_nxt = 0;
			result_is_inf_stage1_nxt = 0;
		end
	end

	always @(posedge clk)
	begin
		operand_align_shift_ff 		<= #1 operand_align_shift_nxt;
		swapped_significand1_ff 	<= #1 swapped_significand1_nxt;
		swapped_significand2_ff 	<= #1 swapped_significand2_nxt;
		exponent1_ff 				<= #1 exponent1;
		exponent2_ff 				<= #1 exponent2;
		result_is_inf_stage1_ff 	<= #1 result_is_inf_stage1_nxt;
		result_is_nan_stage1_ff 	<= #1 result_is_nan_stage1_nxt;
		stage2_operation 			<= #1 operation_i;
		exponent2_larger_ff 		<= #1 exponent2_larger;
	end

	/////////////////////////////////////////////////////////////
	// Stage 2 Adder
	/////////////////////////////////////////////////////////////

	// Select the higher exponent to use as the result exponent
	always @*
	begin
		if (exponent2_larger_ff)
			unnormalized_exponent_nxt = exponent2_ff;
		else
			unnormalized_exponent_nxt = exponent1_ff;
	end

	// Arithmetic shift right to align significands
	assign aligned2_nxt = {{SIGNIFICAND_WIDTH{swapped_significand2_ff[SIGNIFICAND_WIDTH + 2]}}, 
			 swapped_significand2_ff } >> operand_align_shift_ff;

	always @(posedge clk)
	begin
		unnormalized_exponent_ff 	<= #1 unnormalized_exponent_nxt;
		aligned1_ff 				<= #1 swapped_significand1_ff;
		aligned2_ff 				<= #1 aligned2_nxt;
		result_is_inf_stage2_ff 	<= #1 result_is_inf_stage1_ff;
		result_is_nan_stage2_ff 	<= #1 result_is_nan_stage1_ff;
		stage3_operation			<= #1 stage2_operation;
	end


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
			else if (result_is_inf_stage2_ff)
				result_o = { 1'b0, {EXPONENT_WIDTH{1'b1}}, {SIGNIFICAND_WIDTH{1'b0}} };	// inf
			else
				result_o = { result_sign, result_exponent, result_significand[SIGNIFICAND_WIDTH + 2:3] };
		end
		else
		begin
			// Comparison operation
			case (stage3_operation)
				32: result_o = result_equal;  // Equal
				33: result_o = ~result_equal; // Not equal
				34: result_o = ~result_equal & ~result_negative; // Greater than
				35: result_o = ~result_equal & result_negative;   // Less than
				36: result_o = ~result_negative;      // Greater than or equal
				37: result_o = result_equal | result_negative; // Less than or equal
				default: result_o = 0;
			endcase
		end
	end

endmodule
