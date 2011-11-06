module fp_adder_stage3
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input									clk,
	input [5:0]								operation_i,
	output reg[5:0] 						operation_o,
	input[SIGNIFICAND_WIDTH + 2:0] 			significand1_i,
	input[SIGNIFICAND_WIDTH + 2:0] 			significand2_i,
	output reg[SIGNIFICAND_WIDTH + 2:0] 	significand_o,
	output reg 								sign_o,
	input [EXPONENT_WIDTH - 1:0] 			exponent_i, 
	output reg[EXPONENT_WIDTH - 1:0] 		exponent_o,
	input  									result_is_inf_i,
	input  									result_is_nan_i,
	output reg 								result_is_inf_o,
	output reg 								result_is_nan_o);

	wire[SIGNIFICAND_WIDTH + 2:0] 			sum;	// Note: three extra bit for hidden bits and carry.
	reg[SIGNIFICAND_WIDTH + 2:0] 			significand_nxt;
	reg 									sign_nxt;

	initial
	begin
		significand_o = 0;
		exponent_o = 0;
		significand_nxt = 0;
		sign_nxt = 0;
		operation_o = 0;
	end

	// Add
	assign sum = significand1_i + significand2_i;

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
		exponent_o 				<= #1 exponent_i;
		sign_o					<= #1 sign_nxt;
		significand_o			<= #1 significand_nxt;
		operation_o				<= #1 operation_i;
		result_is_inf_o 	<= #1 result_is_inf_i;
		result_is_nan_o 	<= #1 result_is_nan_i;
	end	
endmodule
