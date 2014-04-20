// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
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
