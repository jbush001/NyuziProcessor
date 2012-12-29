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
// Storage for vector registers, 2 read ports and 1 write port.
// When a vector register is updated, the mask field controls which
// 32-bit lanes are changed.  For any lane that has a zero in the mask
// bit, the previous value will remain in the register.
// This has one cycle of latency for reads.
// If a register lane is read and written in the same cycle, X will be returned.
// However, it is legal to write to one lane and read from another line of the
// same register, as each lane is an independent memory bank.
//
// XXX how should this behave when a reset occurs?
//

module vector_register_file(
	input 					clk,
	input					reset,
	input [6:0] 			ds_vector_sel1,
	input [6:0] 			ds_vector_sel2,
	output [511:0] 			vector_value1,
	output [511:0] 			vector_value2,
	input [6:0]				wb_writeback_reg,
	input [511:0]			wb_writeback_value,
	input [15:0]			wb_writeback_mask,
	input					wb_enable_vector_writeback);

	scalar_register_file lane15(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[511:480]),
		.scalar_value2(vector_value2[511:480]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[511:480]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[15]));

	scalar_register_file lane14(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[479:448]),
		.scalar_value2(vector_value2[479:448]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[479:448]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[14]));

	scalar_register_file lane13(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[447:416]),
		.scalar_value2(vector_value2[447:416]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[447:416]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[13]));

	scalar_register_file lane12(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[415:384]),
		.scalar_value2(vector_value2[415:384]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[415:384]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[12]));

	scalar_register_file lane11(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[383:352]),
		.scalar_value2(vector_value2[383:352]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[383:352]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[11]));

	scalar_register_file lane10(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[351:320]),
		.scalar_value2(vector_value2[351:320]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[351:320]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[10]));

	scalar_register_file lane9(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[319:288]),
		.scalar_value2(vector_value2[319:288]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[319:288]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[9]));

	scalar_register_file lane8(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[287:256]),
		.scalar_value2(vector_value2[287:256]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[287:256]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[8]));

	scalar_register_file lane7(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[255:224]),
		.scalar_value2(vector_value2[255:224]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[255:224]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[7]));

	scalar_register_file lane6(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[223:192]),
		.scalar_value2(vector_value2[223:192]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[223:192]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[6]));

	scalar_register_file lane5(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[191:160]),
		.scalar_value2(vector_value2[191:160]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[191:160]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[5]));

	scalar_register_file lane4(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[159:128]),
		.scalar_value2(vector_value2[159:128]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[159:128]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[4]));

	scalar_register_file lane3(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[127:96]),
		.scalar_value2(vector_value2[127:96]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[127:96]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[3]));

	scalar_register_file lane2(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[95:64]),
		.scalar_value2(vector_value2[95:64]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[95:64]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[2]));

	scalar_register_file lane1(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[63:32]),
		.scalar_value2(vector_value2[63:32]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[63:32]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[1]));

	scalar_register_file lane0(
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1[31:0]),
		.scalar_value2(vector_value2[31:0]),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value[31:0]),
		.wb_enable_scalar_writeback(wb_enable_vector_writeback && wb_writeback_mask[0]));
endmodule

