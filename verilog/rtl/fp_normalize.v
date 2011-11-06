module fp_normalize
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH,
	parameter INPUT_SIGNIFICAND_WIDTH = (SIGNIFICAND_WIDTH + 1) * 2)

	(input									clk,
	input [INPUT_SIGNIFICAND_WIDTH - 1:0] 	significand_i,
	output[SIGNIFICAND_WIDTH - 1:0] 		significand_o,
	input[EXPONENT_WIDTH - 1:0] 			exponent_i,
	output reg[EXPONENT_WIDTH - 1:0] 		exponent_o,
	input									sign_i,
	output									sign_o,
	input [5:0]								operation_i,
	output [5:0] 							operation_o,
	input  									result_is_inf_i,
	input  									result_is_nan_i,
	output  								result_is_inf_o,
	output 									result_is_nan_o);

	integer 								highest_bit;
	integer 								bit_index;
	wire[INPUT_SIGNIFICAND_WIDTH - 1:0]		shifter_result;

	// Find the highest set bit in the significand.  Infer a priority encoder.
	always @*
	begin
		highest_bit = 0;
		for (bit_index = 0; bit_index <= INPUT_SIGNIFICAND_WIDTH; bit_index = bit_index + 1)
		begin
			if (significand_i[bit_index])
				highest_bit = bit_index;
		end
	end

	// Adjust the exponent
	always @*
	begin
		// Decrease the exponent by the number of shifted binary digits.
		if (highest_bit == 0)
			exponent_o = 0;
		else
			exponent_o = exponent_i - (INPUT_SIGNIFICAND_WIDTH - highest_bit - 2);
	end

	// Shift the significand
	assign shifter_result = significand_i << (INPUT_SIGNIFICAND_WIDTH - highest_bit);
	assign significand_o = shifter_result[SIGNIFICAND_WIDTH * 2 + 4:SIGNIFICAND_WIDTH + 2];
	assign sign_o = sign_i;
	assign operation_o = operation_i;
	assign result_is_inf_o = result_is_inf_i;
	assign result_is_nan_o = result_is_nan_i;
	
endmodule
