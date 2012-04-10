//
// FP reciprocal stage 1
// - Compute estimate for reciprocal using lookup table
//

module fp_recip_stage1
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input								clk,
	input [SIGNIFICAND_WIDTH - 1:0]		significand_i,
	input [EXPONENT_WIDTH - 1:0]		exponent_i,
	output reg[SIGNIFICAND_WIDTH - 1:0]	significand_o = 0,
	output reg[EXPONENT_WIDTH - 1:0]	exponent_o = 0);

	localparam 							LUT_WIDTH = 10;

	wire[LUT_WIDTH - 1:0]				lut_result;
	reg[SIGNIFICAND_WIDTH - 1:0]		significand_nxt = 0;
	reg[EXPONENT_WIDTH - 1:0]			exponent_nxt = 0;

	reciprocal_rom rom(
		.addr_i(significand_i[22:13]),
		.data_o(lut_result));

	always @*
	begin
		if (significand_i == 0)
		begin
			significand_nxt = { 1'b1, 9'd0, {SIGNIFICAND_WIDTH - LUT_WIDTH{1'b0}} };
			exponent_nxt = 8'd254 - exponent_i + 1;
		end
		else
		begin
			significand_nxt = { lut_result, {SIGNIFICAND_WIDTH - LUT_WIDTH{1'b0}} };
			exponent_nxt = 8'd254 - exponent_i;
		end
	end

	always @(posedge clk)
	begin
		significand_o 		<= #1 significand_nxt;
		exponent_o 			<= #1 exponent_nxt;
	end
endmodule
