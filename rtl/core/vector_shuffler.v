// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

//
// Used by the shuffle() instruction to rearrange vector lanes.
// The low 5 bits of each 32 bit lane in the shuffle input is used to 
// select which lane of the input is routed to each output.
// 

module vector_shuffler(
	input [511:0]			value_i,
	input [511:0]			shuffle_i,
	output [511:0]			result_o);
	
	lane_select_mux #(.ASCENDING_INDEX(0)) sel15(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[483:480]),
		.value_o(result_o[511:480]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel14(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[451:448]),
		.value_o(result_o[479:448]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel13(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[419:416]),
		.value_o(result_o[447:416]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel12(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[387:384]),
		.value_o(result_o[415:384]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel11(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[355:352]),
		.value_o(result_o[383:352]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel10(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[323:320]),
		.value_o(result_o[351:320]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel9(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[291:288]),
		.value_o(result_o[319:288]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel8(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[259:256]),
		.value_o(result_o[287:256]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel7(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[227:224]),
		.value_o(result_o[255:224]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel6(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[195:192]),
		.value_o(result_o[223:192]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel5(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[163:160]),
		.value_o(result_o[191:160]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel4(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[131:128]),
		.value_o(result_o[159:128]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel3(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[99:96]),
		.value_o(result_o[127:96]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel2(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[67:64]),
		.value_o(result_o[95:64]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel1(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[35:32]),
		.value_o(result_o[63:32]));

	lane_select_mux #(.ASCENDING_INDEX(0)) sel0(
		.value_i(value_i[511:0]),
		.lane_select_i(shuffle_i[3:0]),
		.value_o(result_o[31:0]));

endmodule

