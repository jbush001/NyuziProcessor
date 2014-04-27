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

module multi_cycle_execute_stage4(
	input                             clk,
	input                             reset,
	
	// From mx3 stage
	input [`VECTOR_LANES - 1:0]       mx3_mask_value,
	input                             mx3_instruction_valid,
	input decoded_instruction_t       mx3_instruction,
	input thread_idx_t                mx3_thread_idx,
	input subcycle_t                  mx3_subcycle,
	
	// To mx4 stage
	output                            mx4_instruction_valid,
	output decoded_instruction_t      mx4_instruction,
	output [`VECTOR_LANES - 1:0]      mx4_mask_value,
	output thread_idx_t               mx4_thread_idx,
	output subcycle_t                 mx4_subcycle);
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			mx4_instruction <= 0;
			mx4_instruction_valid <= 0;
			mx4_mask_value <= 0;
			mx4_thread_idx <= 0;
			mx4_subcycle <= 0;
		end
		else
		begin
			mx4_instruction <= mx3_instruction;
			mx4_instruction_valid <= mx3_instruction_valid;
			mx4_mask_value <= mx3_mask_value;
			mx4_thread_idx <= mx3_thread_idx;
			mx4_subcycle <= mx3_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
