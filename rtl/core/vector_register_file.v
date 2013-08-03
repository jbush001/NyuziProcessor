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
// If a lane of a specific register is read and written in the same cycle, X will be 
// returned. However, it is legal to write to one lane and read from another lane of 
// the same register, as each lane is an independent memory bank.
//
// XXX Contents of the register file are not cleared during reset.
//

module vector_register_file(
	input 					clk,
	input					reset,
	input [`REG_IDX_WIDTH - 1:0] ds_vector_sel1,
	input [`REG_IDX_WIDTH - 1:0] ds_vector_sel2,
	output [511:0] 			vector_value1,
	output [511:0] 			vector_value2,
	input [`REG_IDX_WIDTH - 1:0]	wb_writeback_reg,
	input [511:0]			wb_writeback_value,
	input [15:0]			wb_writeback_mask,
	input					wb_enable_vector_writeback);

	wire[15:0] enable_writeback = {16{wb_enable_vector_writeback}}
		& wb_writeback_mask;

	scalar_register_file lane[15:0](
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.scalar_value1(vector_value1),
		.scalar_value2(vector_value2),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value),
		.wb_enable_scalar_writeback(enable_writeback));
endmodule

