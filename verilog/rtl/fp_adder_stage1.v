module fp_adder_stage1
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input								clk,
	input [5:0]							operation_i,
	input [TOTAL_WIDTH - 1:0]			operand1_i,
	input [TOTAL_WIDTH - 1:0]			operand2_i,
	output reg[5:0] 					operand_align_shift_o,
	output reg[SIGNIFICAND_WIDTH + 2:0] significand1_o,
	output reg[EXPONENT_WIDTH - 1:0] 	exponent1_o,
	output reg[SIGNIFICAND_WIDTH + 2:0] significand2_o,
	output reg[EXPONENT_WIDTH - 1:0] 	exponent2_o,
	output reg 							result_is_inf_o,
	output reg 							result_is_nan_o,
	output reg 							exponent2_larger_o);

	reg[SIGNIFICAND_WIDTH + 2:0] 		swapped_significand1_nxt;
	reg[SIGNIFICAND_WIDTH + 2:0] 		swapped_significand2_nxt;
	reg 								result_is_inf_nxt;
	reg 								result_is_nan_nxt;
	wire 								sign1;
	wire[EXPONENT_WIDTH - 1:0] 			exponent1;
	wire[SIGNIFICAND_WIDTH - 1:0] 		significand1;
	wire 								sign2;
	wire[EXPONENT_WIDTH - 1:0] 			exponent2;
	wire[SIGNIFICAND_WIDTH - 1:0] 		significand2;
	wire 								exponent2_larger;
	reg[5:0] 							operand_align_shift_nxt;
	wire[EXPONENT_WIDTH:0] 				exponent_difference;	// Note extra carry bit
	reg[SIGNIFICAND_WIDTH + 2:0] 		twos_complement_significand1;
	reg[SIGNIFICAND_WIDTH + 2:0] 		twos_complement_significand2;
	reg 								is_nan1;
	reg 								is_inf1;
	wire 								is_zero1;
	wire 								is_zero2;
	reg 								is_nan2;
	reg 								is_inf2;
	wire								addition;

	initial
	begin
		operand_align_shift_o = 0;
		significand1_o = 0;
		significand2_o = 0;
		exponent1_o = 0;
		exponent2_o = 0;
		result_is_inf_o = 0;
		result_is_nan_o = 0;
		exponent2_larger_o = 0;
		swapped_significand1_nxt = 0;
		swapped_significand2_nxt = 0;
		result_is_inf_nxt = 0;
		result_is_nan_nxt = 0;
		operand_align_shift_nxt = 0;
		twos_complement_significand1 = 0;
		twos_complement_significand2 = 0;
		is_nan1 = 0;
		is_inf1 = 0;
		is_nan2 = 0;
		is_inf2 = 0;
	end

	assign sign1 = operand1_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH];
	assign exponent1 = operand1_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH - 1:SIGNIFICAND_WIDTH];
	assign significand1 = operand1_i[SIGNIFICAND_WIDTH - 1:0];
	assign sign2 = operand2_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH];
	assign exponent2 = operand2_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH - 1:SIGNIFICAND_WIDTH];
	assign significand2 = operand2_i[SIGNIFICAND_WIDTH - 1:0];


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

	assign addition = operation_i == 6'b100000;

	// Convert to 2s complement
	always @*
	begin
		if (sign1)
			twos_complement_significand1 = ~{ 2'b00, ~is_zero1, significand1 } + 1;
		else
			twos_complement_significand1 = { 2'b00, ~is_zero1, significand1 };

		if (sign2 ^ !addition)
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
			if (sign1 != (sign2 ^ !addition) && is_inf1 && is_inf2)
			begin
				// inf - inf = nan
				result_is_nan_nxt = 1;
				result_is_inf_nxt = 0;
			end
			else			
			begin
				// inf +/- anything = inf
				result_is_nan_nxt = 0;
				result_is_inf_nxt = 1;
			end
		end
		else if (is_nan1 || is_nan2)
		begin
			// nan +/- anything = nan
			result_is_nan_nxt = 1;
			result_is_inf_nxt = 0;
		end
		else
		begin
			result_is_nan_nxt = 0;
			result_is_inf_nxt = 0;
		end
	end

	always @(posedge clk)
	begin
		operand_align_shift_o 		<= #1 operand_align_shift_nxt;
		significand1_o 				<= #1 swapped_significand1_nxt;
		significand2_o 				<= #1 swapped_significand2_nxt;
		exponent1_o 				<= #1 exponent1;
		exponent2_o 				<= #1 exponent2;
		result_is_inf_o 			<= #1 result_is_inf_nxt;
		result_is_nan_o 			<= #1 result_is_nan_nxt;
		exponent2_larger_o 			<= #1 exponent2_larger;
	end	


endmodule
