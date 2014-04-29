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
// Floating Point Addition
// - Shift smaller operand to align with larger
//

module multi_cycle_execute_stage2(
	input                                    clk,
	input                                    reset,
                                            
	// From writeback stage                 
	input logic                              wb_rollback_en,
	input thread_idx_t                       wb_rollback_thread_idx,
	input pipeline_sel_t                     wb_rollback_pipeline,
	                                        
	// From mx1 stage                       
	input [`VECTOR_LANES - 1:0]              mx1_mask_value,
	input                                    mx1_instruction_valid,
	input decoded_instruction_t              mx1_instruction,
	input thread_idx_t                       mx1_thread_idx,
	input subcycle_t                         mx1_subcycle,
                                            
	// Floating point addition pipeline                    
	input[`VECTOR_LANES - 1:0][23:0]         mx1_significand1,
	input[`VECTOR_LANES - 1:0][23:0]         mx1_significand2,
	input[`VECTOR_LANES - 1:0]               mx1_logical_subtract,
	input[`VECTOR_LANES - 1:0][4:0]          mx1_shift_amount,
	input[`VECTOR_LANES - 1:0][7:0]          mx1_exponent,
	input [`VECTOR_LANES - 1:0]              mx1_result_sign,
	                                        
	// To mx3 stage                         
	output                                   mx2_instruction_valid,
	output decoded_instruction_t             mx2_instruction,
	output [`VECTOR_LANES - 1:0]             mx2_mask_value,
	output thread_idx_t                      mx2_thread_idx,
	output subcycle_t                        mx2_subcycle,
	
	// Floating point addition pipeline                    
	output logic[`VECTOR_LANES - 1:0]        mx2_logical_subtract,
	output logic[`VECTOR_LANES - 1:0]        mx2_result_sign,
	output logic[`VECTOR_LANES - 1:0][23:0]  mx2_significand1,
	output logic[`VECTOR_LANES - 1:0][23:0]  mx2_significand2,
	output logic[`VECTOR_LANES - 1:0][7:0]   mx2_exponent,
	output logic[`VECTOR_LANES - 1:0]        mx2_guard,
	output logic[`VECTOR_LANES - 1:0]        mx2_round,
	output logic[`VECTOR_LANES - 1:0]        mx2_sticky);

	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic
			logic[23:0] aligned_significand;
			logic guard;
			logic round;
			logic[21:0] sticky_bits;
			logic sticky;
			logic needs_round;
			
			assign { aligned_significand, guard, round, sticky_bits } = { mx1_significand2[lane_idx], 24'd0 } >> 
				mx1_shift_amount[lane_idx];
			assign sticky = |sticky_bits;
			
			// Round towards nearest, 
			assign needs_round = guard && round && !sticky;
		
			always @(posedge clk)
			begin
				mx2_significand1[lane_idx] <= mx1_significand1[lane_idx];
				mx2_significand2[lane_idx] <= aligned_significand;
				mx2_exponent[lane_idx] <= mx1_exponent[lane_idx];
				mx2_logical_subtract[lane_idx] <= mx1_logical_subtract[lane_idx];
				mx2_result_sign[lane_idx] <= mx1_result_sign[lane_idx];
				mx2_guard[lane_idx] <= guard;
				mx2_round[lane_idx] <= round;
				mx2_sticky[lane_idx] <= sticky;
			end
		end
	endgenerate
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			mx2_instruction <= 0;
			mx2_instruction_valid <= 0;
			mx2_mask_value <= 0;
			mx2_thread_idx <= 0;
			mx2_subcycle <= 0;
		end
		else
		begin
			mx2_instruction <= mx1_instruction;
			mx2_instruction_valid <= mx1_instruction_valid && (!wb_rollback_en || wb_rollback_thread_idx != mx1_thread_idx
				|| wb_rollback_pipeline != PIPE_MEM);
			mx2_mask_value <= mx1_mask_value;
			mx2_thread_idx <= mx1_thread_idx;
			mx2_subcycle <= mx1_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
