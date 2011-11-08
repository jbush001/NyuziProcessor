`include "../timescale.v"

module fp_multiplier_stage3
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH,
	parameter SIGNIFICAND_PRODUCT_WIDTH = (SIGNIFICAND_WIDTH + 1) * 2)

	(input										clk,
	input [SIGNIFICAND_PRODUCT_WIDTH + 1:0]		significand_i,
	input [EXPONENT_WIDTH - 1:0] 				exponent_i,
	input 										sign_i,
	output reg[SIGNIFICAND_PRODUCT_WIDTH + 1:0]	significand_o,
	output reg[EXPONENT_WIDTH - 1:0] 			exponent_o,
	output reg									sign_o);

	// XXX placeholder for multi-stage multiplier

	always @(posedge clk)
	begin
		significand_o 				<= #1 significand_i;
		sign_o 						<= #1 sign_i;
		exponent_o 					<= #1 exponent_i;
	end
endmodule