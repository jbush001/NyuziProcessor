//
// First stage of floating point multiplier pipeline
// - Compute result exponent
// - Detect zero result
//
module fp_multiplier_stage1
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH,
	parameter SIGNIFICAND_PRODUCT_WIDTH = (SIGNIFICAND_WIDTH + 1) * 2)

	(input										clk,
	input [5:0]									operation_i,
	input [TOTAL_WIDTH - 1:0]					operand1_i,
	input [TOTAL_WIDTH - 1:0]					operand2_i,
	output reg[31:0]							significand1_o = 0,
	output reg[31:0]							significand2_o = 0,
	output reg[EXPONENT_WIDTH - 1:0] 			exponent_o = 0,
	output reg									sign_o = 0);

	reg 										sign1 = 0;
	reg[EXPONENT_WIDTH - 1:0] 					exponent1 = 0;
	reg[EXPONENT_WIDTH - 1:0] 					result_exponent = 0;
	reg[SIGNIFICAND_PRODUCT_WIDTH + 1:0]	 	significand_product_nxt = 0;

	wire sign2 = operand2_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH];
	wire[EXPONENT_WIDTH - 1:0] exponent2 = operand2_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH - 1:SIGNIFICAND_WIDTH];
	wire result_sign = sign1 ^ sign2;

	// If the first parameter is an integer, treat it as a float now for
	// conversion.
	always @*
	begin
		if (operation_i == 6'b101010)	// SITOF conversion
		begin
			// Note: this is quick and dirty for now. I just truncate the input
			// if it is larger than the significand width.  A smarter approach
			// would detect the various widths and shift.
			sign1 = operand1_i[31];
			exponent1 = SIGNIFICAND_WIDTH + 8'h7f;
			if (sign1)
				significand1_o = (operand1_i ^ {32{1'b1}}) + 1;
			else
				significand1_o = operand1_i;
		end
		else
		begin
			sign1 = operand1_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH];
			exponent1 = operand1_i[EXPONENT_WIDTH + SIGNIFICAND_WIDTH - 1:SIGNIFICAND_WIDTH];
			significand1_o = { 1'b1, operand1_i[SIGNIFICAND_WIDTH - 1:0] };
		end
	end
	
	always @*
	begin
		// If we know the result will be zero, just set the second operand
		// to ensure the result will be zero.
		if (is_zero_nxt)
			significand2_o = 0;
		else
			significand2_o = { 1'b1, operand2_i[SIGNIFICAND_WIDTH - 1:0] };
	end
	
	// Unbias the exponents so we can add them
	wire[EXPONENT_WIDTH - 1:0] unbiased_exponent1 = { ~exponent1[EXPONENT_WIDTH - 1], 
			exponent1[EXPONENT_WIDTH - 2:0] };
	wire[EXPONENT_WIDTH - 1:0] unbiased_exponent2 = { ~exponent2[EXPONENT_WIDTH - 1], 
			exponent2[EXPONENT_WIDTH - 2:0] };

	// The result exponent is simply the sum of the two exponents
	wire[EXPONENT_WIDTH - 1:0] unbiased_result_exponent = unbiased_exponent1 + unbiased_exponent2;

	// Check for zero explicitly, since a leading 1 is otherwise 
	// assumed for the significand
	wire is_zero_nxt = operand1_i == 0 || operand2_i == 0;

	// Re-bias the result exponent.  Note that we subtract the significand width
	// here because of the multiplication.
	always @*
	begin
		if (is_zero_nxt)
			result_exponent = 0;
		else
			result_exponent = { ~unbiased_result_exponent[EXPONENT_WIDTH - 1], 
				unbiased_result_exponent[EXPONENT_WIDTH - 2:0] } + 1;
	end
	
	always @(posedge clk)
	begin
		exponent_o				<= #1 result_exponent;
		sign_o 					<= #1 result_sign;
	end
endmodule
