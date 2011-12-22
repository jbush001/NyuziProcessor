//
// Stage 2 of the floating point addition pipeline
// - Select the higher exponent to use as the result exponent
// - Shift to align significands
// 

module fp_adder_stage2
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input									clk,
	input [5:0]								operation_i,
	input [5:0] 							operand_align_shift_i,
	input [SIGNIFICAND_WIDTH + 2:0] 		significand1_i,
	input [SIGNIFICAND_WIDTH + 2:0] 		significand2_i,
	input [EXPONENT_WIDTH - 1:0] 			exponent1_i,
	input [EXPONENT_WIDTH - 1:0] 			exponent2_i,
	input  									result_is_inf_i,
	input  									result_is_nan_i,
	input  									exponent2_larger_i,
	output reg[EXPONENT_WIDTH - 1:0] 		exponent_o = 0,
	output reg[SIGNIFICAND_WIDTH + 2:0] 	significand1_o = 0,
	output reg[SIGNIFICAND_WIDTH + 2:0] 	significand2_o = 0,
	output reg 								result_is_inf_o = 0,
	output reg 								result_is_nan_o = 0);

	reg[EXPONENT_WIDTH - 1:0] 				unnormalized_exponent_nxt = 0; 

	// Select the higher exponent to use as the result exponent
	always @*
	begin
		if (exponent2_larger_i)
			unnormalized_exponent_nxt = exponent2_i;
		else
			unnormalized_exponent_nxt = exponent1_i;
	end

	// Arithmetic shift right to align significands
	wire[SIGNIFICAND_WIDTH + 2:0]  aligned2_nxt = {{SIGNIFICAND_WIDTH{significand2_i[SIGNIFICAND_WIDTH + 2]}}, 
			 significand2_i } >> operand_align_shift_i;

	always @(posedge clk)
	begin
		exponent_o 	<= #1 unnormalized_exponent_nxt;
		significand1_o 				<= #1 significand1_i;
		significand2_o 				<= #1 aligned2_nxt;
		result_is_inf_o 	<= #1 result_is_inf_i;
		result_is_nan_o 	<= #1 result_is_nan_i;
	end

endmodule
