//
// Used by the shuffle() instruction to rearrange vector lanes.
// The low 5 bits of each 32 bit lane in the shuffle input is used to 
// select which lane of the input is routed to each output.
// 

module vector_shuffler(
	input [511:0]			value_i,
	input [511:0]			shuffle_i,
	output [511:0]			result_o);
	
	lane_select_mux sel15(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[483:480]),
		.value_o(result_o[511:480]));

	lane_select_mux sel14(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[451:448]),
		.value_o(result_o[479:448]));

	lane_select_mux sel13(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[419:416]),
		.value_o(result_o[447:416]));

	lane_select_mux sel12(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[387:384]),
		.value_o(result_o[415:384]));

	lane_select_mux sel11(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[355:352]),
		.value_o(result_o[383:352]));

	lane_select_mux sel10(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[323:320]),
		.value_o(result_o[351:320]));

	lane_select_mux sel9(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[291:288]),
		.value_o(result_o[319:288]));

	lane_select_mux sel8(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[259:256]),
		.value_o(result_o[287:256]));

	lane_select_mux sel7(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[227:224]),
		.value_o(result_o[255:224]));

	lane_select_mux sel6(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[195:192]),
		.value_o(result_o[223:192]));

	lane_select_mux sel5(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[163:160]),
		.value_o(result_o[191:160]));

	lane_select_mux sel4(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[131:128]),
		.value_o(result_o[159:128]));

	lane_select_mux sel3(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[99:96]),
		.value_o(result_o[127:96]));

	lane_select_mux sel2(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[67:64]),
		.value_o(result_o[95:64]));

	lane_select_mux sel1(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[35:32]),
		.value_o(result_o[63:32]));

	lane_select_mux sel0(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[3:0]),
		.value_o(result_o[31:0]));

endmodule

