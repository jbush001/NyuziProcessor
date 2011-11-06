module fp_adder_stage3
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input									clk,
	input[SIGNIFICAND_WIDTH + 2:0] 			significand1_i,
	input[SIGNIFICAND_WIDTH + 2:0] 			significand2_i,
	output reg[SIGNIFICAND_WIDTH + 2:0] 	significand_o,
	output reg 								sign_o);

	wire[SIGNIFICAND_WIDTH + 2:0] 			sum;	// Note: three extra bit for hidden bits and carry.

	// Add
	assign sum = significand1_i + significand2_i;

	// Convert back to ones complement
	always @*
	begin
		if (sum[SIGNIFICAND_WIDTH + 2])
		begin
			significand_o = ~sum + 1;	
			sign_o = 1;
		end
		else
		begin
			significand_o = sum;
			sign_o = 0;
		end
	end
endmodule
