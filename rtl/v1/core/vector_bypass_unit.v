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
// Vector Bypass Unit
//
// Bypasses vector results that have not yet been committed to the register file
// from later stages in the pipeline.  This must bypass each word lane in the
// vector individually because of predication.
//

module vector_bypass_unit
	(input [`REG_IDX_WIDTH - 1:0]     register_sel_i,
	input [`VECTOR_BITS - 1:0]        data_i,
	output [`VECTOR_BITS - 1:0]       value_o,
	input [`REG_IDX_WIDTH - 1:0]      bypass1_register_i,
	input                             bypass1_write_i,
	input [`VECTOR_BITS - 1:0]        bypass1_value_i,
	input [`VECTOR_LANES - 1:0]       bypass1_mask_i,
	input [`REG_IDX_WIDTH - 1:0]      bypass2_register_i,
	input                             bypass2_write_i,
	input [`VECTOR_BITS - 1:0]        bypass2_value_i,
	input [`VECTOR_LANES - 1:0]       bypass2_mask_i,
	input [`REG_IDX_WIDTH - 1:0]      bypass3_register_i,
	input                             bypass3_write_i,
	input [`VECTOR_BITS - 1:0]        bypass3_value_i,
	input [`VECTOR_LANES - 1:0]       bypass3_mask_i,
	input [`REG_IDX_WIDTH - 1:0]      bypass4_register_i,
	input                             bypass4_write_i,
	input [`VECTOR_BITS - 1:0]        bypass4_value_i,
	input [`VECTOR_LANES - 1:0]       bypass4_mask_i);

	wire bypass1_has_value = register_sel_i == bypass1_register_i && bypass1_write_i;
	wire bypass2_has_value = register_sel_i == bypass2_register_i && bypass2_write_i;
	wire bypass3_has_value = register_sel_i == bypass3_register_i && bypass3_write_i;
	wire bypass4_has_value = register_sel_i == bypass4_register_i && bypass4_write_i;

	genvar lane;

	generate 
		for (lane = 0; lane < `VECTOR_LANES; lane++)
		begin : bypass_lane
			assign value_o[lane * 32+:32] = 
				(bypass1_has_value && bypass1_mask_i[lane]) ? bypass1_value_i[lane * 32+:32]
				: (bypass2_has_value && bypass2_mask_i[lane]) ? bypass2_value_i[lane * 32+:32]
				: (bypass3_has_value && bypass3_mask_i[lane]) ? bypass3_value_i[lane * 32+:32]
				: (bypass4_has_value && bypass4_mask_i[lane]) ? bypass4_value_i[lane * 32+:32]
				: data_i[lane * 32+:32];
		end
	endgenerate
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

