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
    input [511:0]       operand1,
    input [511:0]       operand2,
    output [511:0]      single_cycle_result);

    single_cycle_scalar_alu alu15(
        .operation_i(operation_i),
        .operand1(operand1[511:480]),
        .operand2(operand2[511:480]),
        .single_cycle_result(single_cycle_result[511:480]));

    single_cycle_scalar_alu alu14(
        .operation_i(operation_i),
        .operand1(operand1[479:448]),
        .operand2(operand2[479:448]),
        .single_cycle_result(single_cycle_result[479:448]));

    single_cycle_scalar_alu alu13(
        .operation_i(operation_i),
        .operand1(operand1[447:416]),
        .operand2(operand2[447:416]),
        .single_cycle_result(single_cycle_result[447:416]));

    single_cycle_scalar_alu alu12(
        .operation_i(operation_i),
        .operand1(operand1[415:384]),
        .operand2(operand2[415:384]),
        .single_cycle_result(single_cycle_result[415:384]));

    single_cycle_scalar_alu alu11(
        .operation_i(operation_i),
        .operand1(operand1[383:352]),
        .operand2(operand2[383:352]),
        .single_cycle_result(single_cycle_result[383:352]));

    single_cycle_scalar_alu alu10(
        .operation_i(operation_i),
        .operand1(operand1[351:320]),
        .operand2(operand2[351:320]),
        .single_cycle_result(single_cycle_result[351:320]));

    single_cycle_scalar_alu alu9(
        .operation_i(operation_i),
        .operand1(operand1[319:288]),
        .operand2(operand2[319:288]),
        .single_cycle_result(single_cycle_result[319:288]));

    single_cycle_scalar_alu alu8(
        .operation_i(operation_i),
        .operand1(operand1[287:256]),
        .operand2(operand2[287:256]),
        .single_cycle_result(single_cycle_result[287:256]));

    single_cycle_scalar_alu alu7(
        .operation_i(operation_i),
        .operand1(operand1[255:224]),
        .operand2(operand2[255:224]),
        .single_cycle_result(single_cycle_result[255:224]));

    single_cycle_scalar_alu alu6(
        .operation_i(operation_i),
        .operand1(operand1[223:192]),
        .operand2(operand2[223:192]),
        .single_cycle_result(single_cycle_result[223:192]));

    single_cycle_scalar_alu alu5(
        .operation_i(operation_i),
        .operand1(operand1[191:160]),
        .operand2(operand2[191:160]),
        .single_cycle_result(single_cycle_result[191:160]));

    single_cycle_scalar_alu alu4(
        .operation_i(operation_i),
        .operand1(operand1[159:128]),
        .operand2(operand2[159:128]),
        .single_cycle_result(single_cycle_result[159:128]));

    single_cycle_scalar_alu alu3(
        .operation_i(operation_i),
        .operand1(operand1[127:96]),
        .operand2(operand2[127:96]),
        .single_cycle_result(single_cycle_result[127:96]));

    single_cycle_scalar_alu alu2(
        .operation_i(operation_i),
        .operand1(operand1[95:64]),
        .operand2(operand2[95:64]),
        .single_cycle_result(single_cycle_result[95:64]));

    single_cycle_scalar_alu alu1(
        .operation_i(operation_i),
        .operand1(operand1[63:32]),
        .operand2(operand2[63:32]),
        .single_cycle_result(single_cycle_result[63:32]));

    single_cycle_scalar_alu alu0(
        .operation_i(operation_i),
        .operand1(operand1[31:0]),
        .operand2(operand2[31:0]),
        .single_cycle_result(single_cycle_result[31:0]));

endmodule
