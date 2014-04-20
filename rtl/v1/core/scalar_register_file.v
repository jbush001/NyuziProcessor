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

`include "defines.v"

//
// Storage for scalar registers, 2 read ports and 1 write port.
// This has one cycle of latency for reads.
// If a register is read and written in the same cycle, X will be returned.
//
// XXX Contents of the register file are not cleared during reset.
//

module scalar_register_file(
	input                          clk,
	input                          reset,
	input [`REG_IDX_WIDTH - 1:0]   ds_scalar_sel1,
	input [`REG_IDX_WIDTH - 1:0]   ds_scalar_sel2,
	output logic[31:0]             rf_scalar_value1,
	output logic[31:0]             rf_scalar_value2,
	input [`REG_IDX_WIDTH - 1:0]   wb_writeback_reg,
	input [31:0]                   wb_writeback_value,
	input                          wb_enable_scalar_writeback);

	localparam TOTAL_REGISTERS = `STRANDS_PER_CORE * 32; // 32 registers per strand * strands

	logic[31:0] registers[TOTAL_REGISTERS];	
	
	always_ff @(posedge clk)
	begin
		if (ds_scalar_sel1 == wb_writeback_reg && wb_enable_scalar_writeback)
			rf_scalar_value1 <= 32'dx;
		else
			rf_scalar_value1 <= registers[ds_scalar_sel1];

		if (ds_scalar_sel2 == wb_writeback_reg && wb_enable_scalar_writeback)
			rf_scalar_value2 <= 32'dx;
		else
			rf_scalar_value2 <= registers[ds_scalar_sel2];
		
		if (wb_enable_scalar_writeback)
			registers[wb_writeback_reg] <= wb_writeback_value;
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
