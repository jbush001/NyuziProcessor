
module multi_cycle_vector_alu(
	input				clk,
	input [5:0]			operation_i,
	input [511:0]		operand1_i,
	input [511:0]		operand2_i,
	output [511:0]		result_o);

	multi_cycle_scalar_alu alu15(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[511:480]),
		.operand2_i(operand2_i[511:480]),
		.result_o(result_o[511:480]));

	multi_cycle_scalar_alu alu14(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[479:448]),
		.operand2_i(operand2_i[479:448]),
		.result_o(result_o[479:448]));

	multi_cycle_scalar_alu alu13(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[447:416]),
		.operand2_i(operand2_i[447:416]),
		.result_o(result_o[447:416]));

	multi_cycle_scalar_alu alu12(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[415:384]),
		.operand2_i(operand2_i[415:384]),
		.result_o(result_o[415:384]));

	multi_cycle_scalar_alu alu11(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[383:352]),
		.operand2_i(operand2_i[383:352]),
		.result_o(result_o[383:352]));

	multi_cycle_scalar_alu alu10(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[351:320]),
		.operand2_i(operand2_i[351:320]),
		.result_o(result_o[351:320]));

	multi_cycle_scalar_alu alu9(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[319:288]),
		.operand2_i(operand2_i[319:288]),
		.result_o(result_o[319:288]));

	multi_cycle_scalar_alu alu8(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[287:256]),
		.operand2_i(operand2_i[287:256]),
		.result_o(result_o[287:256]));

	multi_cycle_scalar_alu alu7(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[255:224]),
		.operand2_i(operand2_i[255:224]),
		.result_o(result_o[255:224]));

	multi_cycle_scalar_alu alu6(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[223:192]),
		.operand2_i(operand2_i[223:192]),
		.result_o(result_o[223:192]));

	multi_cycle_scalar_alu alu5(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[191:160]),
		.operand2_i(operand2_i[191:160]),
		.result_o(result_o[191:160]));

	multi_cycle_scalar_alu alu4(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[159:128]),
		.operand2_i(operand2_i[159:128]),
		.result_o(result_o[159:128]));

	multi_cycle_scalar_alu alu3(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[127:96]),
		.operand2_i(operand2_i[127:96]),
		.result_o(result_o[127:96]));

	multi_cycle_scalar_alu alu2(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[95:64]),
		.operand2_i(operand2_i[95:64]),
		.result_o(result_o[95:64]));

	multi_cycle_scalar_alu alu1(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[63:32]),
		.operand2_i(operand2_i[63:32]),
		.result_o(result_o[63:32]));

	multi_cycle_scalar_alu alu0(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i[31:0]),
		.operand2_i(operand2_i[31:0]),
		.result_o(result_o[31:0]));

endmodule
