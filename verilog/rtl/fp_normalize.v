// 
// Given a floating point number that is not normalized (has the leading one
// and possibly some number of zeroes in front of it), output the same number in 
// normalized form, shifting the significand and adjusting the exponent.
//

module fp_normalize
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH,
	parameter INPUT_SIGNIFICAND_WIDTH = (SIGNIFICAND_WIDTH + 1) * 2)

	(input									clk,
	input [INPUT_SIGNIFICAND_WIDTH - 1:0] 	significand_i,
	output [SIGNIFICAND_WIDTH - 1:0] 		significand_o,
	input [EXPONENT_WIDTH - 1:0] 			exponent_i,
	output [EXPONENT_WIDTH - 1:0] 			exponent_o,
	input									sign_i,
	output									sign_o,
	input [5:0]								operation_i,
	input  									result_is_inf_i,
	input  									result_is_nan_i,
	output  								result_is_inf_o,
	output 									result_is_nan_o);

	reg[5:0] 								highest_bit = 0;
	reg[5:0] 								bit_index = 0;

	// Find the highest set bit in the significand.  Infer a priority encoder.
	always @*
	begin
		highest_bit = 0;
		for (bit_index = 0; bit_index < INPUT_SIGNIFICAND_WIDTH; bit_index = bit_index + 1)
		begin
			if (significand_i[bit_index])
				highest_bit = bit_index;
		end
	end

	// Adjust the exponent
	wire[EXPONENT_WIDTH - 1:0] exponent_delta = (INPUT_SIGNIFICAND_WIDTH - highest_bit - 2);
	assign exponent_o = (highest_bit == 0) ? 0 : exponent_i - exponent_delta;

	// Shift the significand
	wire[5:0] shift_amount = INPUT_SIGNIFICAND_WIDTH - highest_bit;
	wire[INPUT_SIGNIFICAND_WIDTH - 1:0] shifter_result = significand_i << shift_amount;
	assign significand_o = shifter_result[SIGNIFICAND_WIDTH * 2 + 1:SIGNIFICAND_WIDTH + 2];
	assign sign_o = sign_i;
	assign result_is_inf_o = result_is_inf_i;
	assign result_is_nan_o = result_is_nan_i;
endmodule

