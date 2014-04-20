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
	input                            clk,
	input                            reset,
	input [`REG_IDX_WIDTH - 1:0]     ds_vector_sel1,
	input [`REG_IDX_WIDTH - 1:0]     ds_vector_sel2,
	output [`VECTOR_BITS - 1:0]      rf_vector_value1,
	output [`VECTOR_BITS - 1:0]      rf_vector_value2,
	input [`REG_IDX_WIDTH - 1:0]     wb_writeback_reg,
	input [`VECTOR_BITS - 1:0]       wb_writeback_value,
	input [`VECTOR_LANES - 1:0]      wb_writeback_mask,
	input                            wb_enable_vector_writeback);

	wire[`VECTOR_LANES - 1:0] enable_writeback = {`VECTOR_LANES{wb_enable_vector_writeback}}
		& wb_writeback_mask;

	scalar_register_file lane[`VECTOR_LANES - 1:0](
		.clk(clk),
		.reset(reset),
		.ds_scalar_sel1(ds_vector_sel1),
		.ds_scalar_sel2(ds_vector_sel2),
		.rf_scalar_value1(rf_vector_value1),
		.rf_scalar_value2(rf_vector_value2),
		.wb_writeback_reg(wb_writeback_reg),
		.wb_writeback_value(wb_writeback_value),
		.wb_enable_scalar_writeback(enable_writeback));
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


