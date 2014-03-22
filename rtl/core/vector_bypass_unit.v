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
		for (lane = 0; lane < `VECTOR_LANES; lane = lane + 1)
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

