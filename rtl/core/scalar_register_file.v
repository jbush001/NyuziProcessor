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
// Storage for scalar registers, 2 read ports and 1 write port.
// This has one cycle of latency for reads.
// If a register is read and written in the same cycle, X will be returned.
//
// XXX how should this behave when a reset occurs?
//

module scalar_register_file(
	input 					clk,
	input					reset,
	input [6:0] 			ds_scalar_sel1,
	input [6:0] 			ds_scalar_sel2,
	output reg[31:0] 		scalar_value1,
	output reg[31:0] 		scalar_value2,
	input [6:0] 			wb_writeback_reg,
	input [31:0] 			wb_writeback_value,
	input 					wb_enable_scalar_writeback);

	localparam NUM_REGISTERS = 4 * 32; // 32 registers per strand * 4 strands

	reg[31:0] registers[0:NUM_REGISTERS - 1];	
	
	initial
	begin : init
		integer i;
	
		for (i = 0; i < NUM_REGISTERS; i = i + 1)
			registers[i] = 0;
	end

	always @(posedge clk)
	begin
		if (ds_scalar_sel1 == wb_writeback_reg && wb_enable_scalar_writeback)
			scalar_value1 <= 32'dx;
		else
			scalar_value1 <= registers[ds_scalar_sel1];

		if (ds_scalar_sel2 == wb_writeback_reg && wb_enable_scalar_writeback)
			scalar_value2 <= 32'dx;
		else
			scalar_value2 <= registers[ds_scalar_sel2];
		
		if (wb_enable_scalar_writeback)
			registers[wb_writeback_reg] <= wb_writeback_value;
	end
endmodule
