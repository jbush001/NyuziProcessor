module fp_adder_stage2
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input									clk,
	input [5:0]								operation_i,
	input [5:0] 							operand_align_shift_i,
	input [SIGNIFICAND_WIDTH + 2:0] 		swapped_significand1_i,
	input [SIGNIFICAND_WIDTH + 2:0] 		swapped_significand2_i,
	input [EXPONENT_WIDTH - 1:0] 			exponent1_i,
	input [EXPONENT_WIDTH - 1:0] 			exponent2_i,
	input  									result_is_inf_stage1_i,
	input  									result_is_nan_stage1_i,
	input  									exponent2_larger_i,
	output reg[EXPONENT_WIDTH - 1:0] 		unnormalized_exponent_ff,
	output reg[SIGNIFICAND_WIDTH + 2:0] 	aligned1_ff,
	output reg[SIGNIFICAND_WIDTH + 2:0] 	aligned2_ff,
	output reg 								adder_result_is_inf_stage2,
	output reg 								result_is_nan_stage2_ff,
	output reg[5:0] 						operation_o);

	reg[EXPONENT_WIDTH - 1:0] 				unnormalized_exponent_nxt; 
	wire[SIGNIFICAND_WIDTH + 2:0] 			aligned2_nxt;

	initial
	begin
		unnormalized_exponent_ff = 0;
		aligned1_ff = 0;
		aligned2_ff = 0;
		adder_result_is_inf_stage2 = 0;
		result_is_nan_stage2_ff = 0;
		operation_o = 0;
		unnormalized_exponent_nxt = 0;	
	end

	// Select the higher exponent to use as the result exponent
	always @*
	begin
		if (exponent2_larger_i)
			unnormalized_exponent_nxt = exponent2_i;
		else
			unnormalized_exponent_nxt = exponent1_i;
	end

	// Arithmetic shift right to align significands
	assign aligned2_nxt = {{SIGNIFICAND_WIDTH{swapped_significand2_i[SIGNIFICAND_WIDTH + 2]}}, 
			 swapped_significand2_i } >> operand_align_shift_i;

	always @(posedge clk)
	begin
		unnormalized_exponent_ff 	<= #1 unnormalized_exponent_nxt;
		aligned1_ff 				<= #1 swapped_significand1_i;
		aligned2_ff 				<= #1 aligned2_nxt;
		adder_result_is_inf_stage2 	<= #1 result_is_inf_stage1_i;
		result_is_nan_stage2_ff 	<= #1 result_is_nan_stage1_i;
		operation_o					<= #1 operation_i;
	end

endmodule
