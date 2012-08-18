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
// 16 instances of single-cycle scalar ALUs, one for each vector lane
//

module single_cycle_vector_alu(
    input [5:0]         operation_i,
    input [511:0]       operand1_i,
    input [511:0]       operand2_i,
    output [511:0]      result_o);

    single_cycle_scalar_alu alu15(
        .operation_i(operation_i),
        .operand1_i(operand1_i[511:480]),
        .operand2_i(operand2_i[511:480]),
        .result_o(result_o[511:480]));

    single_cycle_scalar_alu alu14(
        .operation_i(operation_i),
        .operand1_i(operand1_i[479:448]),
        .operand2_i(operand2_i[479:448]),
        .result_o(result_o[479:448]));

    single_cycle_scalar_alu alu13(
        .operation_i(operation_i),
        .operand1_i(operand1_i[447:416]),
        .operand2_i(operand2_i[447:416]),
        .result_o(result_o[447:416]));

    single_cycle_scalar_alu alu12(
        .operation_i(operation_i),
        .operand1_i(operand1_i[415:384]),
        .operand2_i(operand2_i[415:384]),
        .result_o(result_o[415:384]));

    single_cycle_scalar_alu alu11(
        .operation_i(operation_i),
        .operand1_i(operand1_i[383:352]),
        .operand2_i(operand2_i[383:352]),
        .result_o(result_o[383:352]));

    single_cycle_scalar_alu alu10(
        .operation_i(operation_i),
        .operand1_i(operand1_i[351:320]),
        .operand2_i(operand2_i[351:320]),
        .result_o(result_o[351:320]));

    single_cycle_scalar_alu alu9(
        .operation_i(operation_i),
        .operand1_i(operand1_i[319:288]),
        .operand2_i(operand2_i[319:288]),
        .result_o(result_o[319:288]));

    single_cycle_scalar_alu alu8(
        .operation_i(operation_i),
        .operand1_i(operand1_i[287:256]),
        .operand2_i(operand2_i[287:256]),
        .result_o(result_o[287:256]));

    single_cycle_scalar_alu alu7(
        .operation_i(operation_i),
        .operand1_i(operand1_i[255:224]),
        .operand2_i(operand2_i[255:224]),
        .result_o(result_o[255:224]));

    single_cycle_scalar_alu alu6(
        .operation_i(operation_i),
        .operand1_i(operand1_i[223:192]),
        .operand2_i(operand2_i[223:192]),
        .result_o(result_o[223:192]));

    single_cycle_scalar_alu alu5(
        .operation_i(operation_i),
        .operand1_i(operand1_i[191:160]),
        .operand2_i(operand2_i[191:160]),
        .result_o(result_o[191:160]));

    single_cycle_scalar_alu alu4(
        .operation_i(operation_i),
        .operand1_i(operand1_i[159:128]),
        .operand2_i(operand2_i[159:128]),
        .result_o(result_o[159:128]));

    single_cycle_scalar_alu alu3(
        .operation_i(operation_i),
        .operand1_i(operand1_i[127:96]),
        .operand2_i(operand2_i[127:96]),
        .result_o(result_o[127:96]));

    single_cycle_scalar_alu alu2(
        .operation_i(operation_i),
        .operand1_i(operand1_i[95:64]),
        .operand2_i(operand2_i[95:64]),
        .result_o(result_o[95:64]));

    single_cycle_scalar_alu alu1(
        .operation_i(operation_i),
        .operand1_i(operand1_i[63:32]),
        .operand2_i(operand2_i[63:32]),
        .result_o(result_o[63:32]));

    single_cycle_scalar_alu alu0(
        .operation_i(operation_i),
        .operand1_i(operand1_i[31:0]),
        .operand2_i(operand2_i[31:0]),
        .result_o(result_o[31:0]));

endmodule
