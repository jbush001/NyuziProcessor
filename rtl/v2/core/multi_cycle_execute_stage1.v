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

module multi_cycle_execute_stage1(
	input                             clk,
	input                             reset,
	
	// From operand fetch stage
	input vector_t                    of_operand1,
	input vector_t                    of_operand2,
	input [`VECTOR_LANES - 1:0]       of_mask_value,
	input                             of_instruction_valid,
	input decoded_instruction_t       of_instruction,
	input thread_idx_t                of_thread_idx,
	input subcycle_t                  of_subcycle,
	
	// From writeback stage
	input logic                       wb_rollback_en,
	input thread_idx_t                wb_rollback_thread_idx,
	
	// To mx2 stage
	output                            mx1_instruction_valid,
	output decoded_instruction_t      mx1_instruction,
	output [`VECTOR_LANES - 1:0]      mx1_mask_value,
	output thread_idx_t               mx1_thread_idx,
	output subcycle_t                 mx1_subcycle);
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			mx1_instruction <= 0;
			mx1_instruction_valid <= 0;
			mx1_mask_value <= 0;
			mx1_thread_idx <= 0;
			mx1_subcycle <= 0;
		end
		else
		begin
			mx1_instruction_valid <= of_instruction_valid && (!wb_rollback_en || wb_rollback_thread_idx != of_thread_idx);
			mx1_instruction <= of_instruction;
			mx1_instruction_valid <= of_instruction_valid;
			mx1_mask_value <= of_mask_value;
			mx1_thread_idx <= of_thread_idx;
			mx1_subcycle <= of_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
