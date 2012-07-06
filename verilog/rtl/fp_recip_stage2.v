//
// This is a stub for now. It should refine the estimate using a newton-raphson
// iteration
//

module fp_recip_stage2
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input								clk,
	input [SIGNIFICAND_WIDTH - 1:0]		significand_i,
	input [EXPONENT_WIDTH - 1:0]		exponent_i,
	input								sign_i,
	output reg[SIGNIFICAND_WIDTH - 1:0]	significand_o = 0,
	output reg[EXPONENT_WIDTH - 1:0]	exponent_o = 0,
	output reg							sign_o = 0);

	always @(posedge clk)
	begin
		significand_o 			<= #1 significand_i;
		exponent_o 				<= #1 exponent_i;	
		sign_o 					<= #1 sign_i;
	end

endmodule
