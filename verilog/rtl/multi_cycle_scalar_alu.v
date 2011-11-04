module multi_cycle_scalar_alu(
	input				clk,
	input [5:0]			operation_i,
	input [31:0]		operand1_i,
	input [31:0]		operand2_i,
	output reg [31:0]	result_o);

	always @*
		result_o <= operand1_i + operand2_i;	// XXX placeholder

endmodule
