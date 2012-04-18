//
// Stage 3 of floating point addition pipeline
// - Add significands
// - Convert result back to ones complement
// 

module fp_adder_stage3
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input									clk,
	input[SIGNIFICAND_WIDTH + 2:0] 			add2_significand1,
	input[SIGNIFICAND_WIDTH + 2:0] 			add2_significand2,
	output reg[SIGNIFICAND_WIDTH + 2:0] 	add3_significand = 0,
	output reg 								add3_sign = 0,
	input [EXPONENT_WIDTH - 1:0] 			add2_exponent, 
	output reg[EXPONENT_WIDTH - 1:0] 		add3_exponent = 0,
	input  									add2_result_is_inf,
	input  									add2_result_is_nan,
	output reg 								add3_result_is_inf = 0,
	output reg 								add3_result_is_nan = 0);

	reg[SIGNIFICAND_WIDTH + 2:0] 			significand_nxt = 0;
	reg 									sign_nxt = 0;

	// Add
	wire[SIGNIFICAND_WIDTH + 2:0] sum = add2_significand1 + add2_significand2;

	// Convert back to ones complement
	always @*
	begin
		if (sum[SIGNIFICAND_WIDTH + 2])
		begin
			significand_nxt = ~sum + 1;	
			sign_nxt = 1;
		end
		else
		begin
			significand_nxt = sum;
			sign_nxt = 0;
		end
	end
	
	always @(posedge clk)
	begin
		add3_exponent 				<= #1 add2_exponent;
		add3_sign					<= #1 sign_nxt;
		add3_significand			<= #1 significand_nxt;
		add3_result_is_inf 		<= #1 add2_result_is_inf;
		add3_result_is_nan 		<= #1 add2_result_is_nan;
	end	
endmodule
