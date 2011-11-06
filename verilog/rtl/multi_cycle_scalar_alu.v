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
	wire[SIGNIFICAND_WIDTH + 2:0] 		add1_significand1;
	wire[SIGNIFICAND_WIDTH + 2:0] 		add1_significand2;
	wire[EXPONENT_WIDTH - 1:0] 			add1_exponent1;
	wire[EXPONENT_WIDTH - 1:0] 			add1_exponent2;
	wire 								add1_result_is_inf;
	wire 								add1_result_is_nan;
	wire[5:0] 							add1_operation;
	wire 								add1_exponent2_larger;
	wire[EXPONENT_WIDTH - 1:0] 			add2_exponent; 
	wire[SIGNIFICAND_WIDTH + 2:0] 		add2_significand1;
	wire[SIGNIFICAND_WIDTH + 2:0] 		add2_significand2;
	wire 								add2_result_is_inf;
	wire 								add2_result_is_nan;
	wire[5:0] 							add2_operation;
	wire[SIGNIFICAND_WIDTH + 2:0] 		add3_significand;
	wire 								add3_sign;

	// normalize
	wire[EXPONENT_WIDTH - 1:0] 			result_exponent;
	wire[SIGNIFICAND_WIDTH + 2:0] 		result_significand;

	wire 								addition;
	wire 								result_equal;
	wire 								result_negative;

	initial
	begin
		result_o = 0;
	end

	fp_adder_stage1 add1(
		.clk(clk),
		.operation_i(operation_i),
		.operation_o(add1_operation),
		.operand1_i(operand1_i),
		.operand2_i(operand2_i),
		.operand_align_shift_o(add1_operand_align_shift),
		.significand1_o(add1_significand1),
		.exponent1_o(add1_exponent1),
		.significand2_o(add1_significand2),
		.exponent2_o(add1_exponent2),
		.result_is_inf_o(add1_result_is_inf),
		.result_is_nan_o(add1_result_is_nan),
		.exponent2_larger_o(add1_exponent2_larger));

	fp_adder_stage2 add2(
		.clk(clk),
		.operation_i(add1_operation),
		.operation_o(add2_operation),
		.operand_align_shift_i(add1_operand_align_shift),
		.significand1_i(add1_significand1),
		.significand2_i(add1_significand2),
		.exponent1_i(add1_exponent1),
		.exponent2_i(add1_exponent2),
		.exponent2_larger_i(add1_exponent2_larger),
		.result_is_inf_i(add1_result_is_inf),
		.result_is_inf_o(add2_result_is_inf),
		.result_is_nan_i(add1_result_is_nan),
		.result_is_nan_o(add2_result_is_nan),
		.exponent_o(add2_exponent),
		.significand1_o(add2_significand1),
		.significand2_o(add2_significand2));

	fp_adder_stage3 add3(
		.clk(clk),
		.significand1_i(add2_significand1),
		.significand2_i(add2_significand2),
		.significand_o(add3_significand),
		.sign_o(add3_sign));

	fp_normalize norm(
		.clk(clk),
		.significand_i(add3_significand),
		.significand_o(result_significand),
		.exponent_i(add2_exponent),
		.exponent_o(result_exponent));

	assign result_equal = result_exponent == 0 && result_significand[SIGNIFICAND_WIDTH + 2:3] == 0;
	assign result_negative = add3_sign == 1;

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
				result_o = { add3_sign, result_exponent, result_significand[SIGNIFICAND_WIDTH + 2:3] };
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
