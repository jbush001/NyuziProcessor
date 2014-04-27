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

module multi_cycle_execute_stage(
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
	input pipeline_sel_t              wb_rollback_pipeline,
	
	// To writeback stage
	output                            mx_instruction_valid,
	output decoded_instruction_t      mx_instruction,
	output vector_t                   mx_result,
	output [`VECTOR_LANES - 1:0]      mx_mask_value,
	output thread_idx_t               mx_thread_idx,
	output subcycle_t                 mx_subcycle);

	decoded_instruction_t mx1_instruction;
	decoded_instruction_t mx2_instruction;
	decoded_instruction_t mx3_instruction;
	decoded_instruction_t mx4_instruction;
	logic mx1_valid;
	logic mx2_valid;
	logic mx3_valid;
	logic mx4_valid;
	logic[`VECTOR_LANES - 1:0] mx1_mask_value;
	logic[`VECTOR_LANES - 1:0] mx2_mask_value;
	logic[`VECTOR_LANES - 1:0] mx3_mask_value;
	logic[`VECTOR_LANES - 1:0] mx4_mask_value;
	thread_idx_t mx1_thread_idx;
	thread_idx_t mx2_thread_idx;
	thread_idx_t mx3_thread_idx;
	thread_idx_t mx4_thread_idx;
	subcycle_t mx1_subcycle;
	subcycle_t mx2_subcycle;
	subcycle_t mx3_subcycle;
	subcycle_t mx4_subcycle;

	assign mx_result = 0;
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			mx1_instruction <= 0;
			mx2_instruction <= 0;
			mx3_instruction <= 0;
			mx4_instruction <= 0;
			mx1_valid <= 0;
			mx2_valid <= 0;
			mx3_valid <= 0;
			mx4_valid <= 0;
			mx1_mask_value <= 0;
			mx2_mask_value <= 0;
			mx3_mask_value <= 0;
			mx4_mask_value <= 0;
			mx1_thread_idx <= 0;
			mx2_thread_idx <= 0;
			mx3_thread_idx <= 0;
			mx4_thread_idx <= 0;
			mx1_subcycle <= 0;
			mx2_subcycle <= 0;
			mx3_subcycle <= 0;
			mx4_subcycle <= 0;
		end
		else
		begin
			mx1_instruction <= of_instruction;
			mx2_instruction <= mx1_instruction;
			mx3_instruction <= mx2_instruction;
			mx4_instruction <= mx3_instruction;
			mx1_valid <= of_instruction_valid;
			mx2_valid <= mx1_valid;
			mx3_valid <= mx2_valid;
			mx4_valid <= mx3_valid;
			mx1_mask_value <= of_mask_value;
			mx2_mask_value <= mx1_mask_value;
			mx3_mask_value <= mx2_mask_value;
			mx4_mask_value <= mx3_mask_value;
			mx_mask_value <= mx4_mask_value;
			mx1_thread_idx <= of_thread_idx;
			mx2_thread_idx <= mx1_thread_idx;
			mx3_thread_idx <= mx2_thread_idx;
			mx4_thread_idx <= mx3_thread_idx;
			mx1_subcycle <= of_subcycle;
			mx2_subcycle <= mx1_subcycle;
			mx3_subcycle <= mx2_subcycle;
			mx4_subcycle <= mx3_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
