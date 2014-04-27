//
// Copyright (C) 2014 Jeff Bush
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
// - Perform operations that only require multiple stages (floating point)
// 

module multi_cycle_execute_stage3(
	input                             clk,
	input                             reset,
	
	// From mx2 stage
	input [`VECTOR_LANES - 1:0]       mx2_mask_value,
	input                             mx2_instruction_valid,
	input decoded_instruction_t       mx2_instruction,
	input thread_idx_t                mx2_thread_idx,
	input subcycle_t                  mx2_subcycle,
	
	// To mx3 stage
	output                            mx3_instruction_valid,
	output decoded_instruction_t      mx3_instruction,
	output [`VECTOR_LANES - 1:0]      mx3_mask_value,
	output thread_idx_t               mx3_thread_idx,
	output subcycle_t                 mx3_subcycle);
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			mx3_instruction <= 0;
			mx3_instruction_valid <= 0;
			mx3_mask_value <= 0;
			mx3_thread_idx <= 0;
			mx3_subcycle <= 0;
		end
		else
		begin
			mx3_instruction <= mx2_instruction;
			mx3_instruction_valid <= mx2_instruction_valid;
			mx3_mask_value <= mx2_mask_value;
			mx3_thread_idx <= mx2_thread_idx;
			mx3_subcycle <= mx2_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
