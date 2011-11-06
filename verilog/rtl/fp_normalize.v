module fp_normalize
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input									clk,
	input [SIGNIFICAND_WIDTH + 2:0] 		significand_i,
	output[SIGNIFICAND_WIDTH + 2:0] 		significand_o,
	input[EXPONENT_WIDTH - 1:0] 			exponent_i,
	output reg[EXPONENT_WIDTH - 1:0] 		exponent_o);

	integer 							highest_bit;
	integer 							bit_index;

	// Find the highest set bit in the significand.  Infer a priority encoder.
	always @*
	begin
		highest_bit = 0;
		for (bit_index = 0; bit_index <= SIGNIFICAND_WIDTH + 2; bit_index = bit_index + 1)
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
			exponent_o = exponent_i - (SIGNIFICAND_WIDTH - highest_bit);
	end

	// Shift the significand
	assign significand_o = significand_i << (SIGNIFICAND_WIDTH + 3 - highest_bit);

	
endmodule
