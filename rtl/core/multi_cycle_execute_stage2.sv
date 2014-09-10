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

`include "defines.sv"

//
// Multicycle execution pipeline stage 2
//
// Floating Point Addition
// - Shift smaller operand to align with larger
// Floating Point multiplication
// - Perform actual operation (XXX placeholder, see below)
//

module multi_cycle_execute_stage2(
	input                                    clk,
	input                                    reset,
                                            
	// From writeback stage                 
	input logic                              wb_rollback_en,
	input thread_idx_t                       wb_rollback_thread_idx,
	input pipeline_sel_t                     wb_rollback_pipeline,
	                                        
	// From mx1 stage                       
	input vector_lane_mask_t                 mx1_mask_value,
	input                                    mx1_instruction_valid,
	input decoded_instruction_t              mx1_instruction,
	input thread_idx_t                       mx1_thread_idx,
	input subcycle_t                         mx1_subcycle,
	input [`VECTOR_LANES - 1:0]              mx1_result_is_inf,
	input [`VECTOR_LANES - 1:0]              mx1_result_is_nan,
                                            
	// Floating point addition/subtraction                    
	input scalar_t[`VECTOR_LANES - 1:0]      mx1_significand_le,
	input scalar_t[`VECTOR_LANES - 1:0]      mx1_significand_se,
	input [`VECTOR_LANES - 1:0]              mx1_logical_subtract,
	input [`VECTOR_LANES - 1:0][5:0]         mx1_se_align_shift,
	input [`VECTOR_LANES - 1:0][7:0]         mx1_add_exponent,
	input [`VECTOR_LANES - 1:0]              mx1_add_result_sign,

	// Floating point multiplication
	input [`VECTOR_LANES - 1:0][7:0]         mx1_mul_exponent,
	input [`VECTOR_LANES - 1:0]              mx1_mul_sign,
	input [`VECTOR_LANES - 1:0][31:0]        mx1_multiplicand,
	input [`VECTOR_LANES - 1:0][31:0]        mx1_multiplier,
	                                        
	// To mx3 stage                         
	output                                   mx2_instruction_valid,
	output decoded_instruction_t             mx2_instruction,
	output vector_lane_mask_t                mx2_mask_value,
	output thread_idx_t                      mx2_thread_idx,
	output subcycle_t                        mx2_subcycle,
	output logic[`VECTOR_LANES - 1:0]        mx2_result_is_inf,
	output logic[`VECTOR_LANES - 1:0]        mx2_result_is_nan,
	
	// Floating point addition/subtraction                    
	output logic[`VECTOR_LANES - 1:0]        mx2_logical_subtract,
	output logic[`VECTOR_LANES - 1:0]        mx2_add_result_sign,
	output scalar_t[`VECTOR_LANES - 1:0]     mx2_significand_le,
	output scalar_t[`VECTOR_LANES - 1:0]     mx2_significand_se,
	output logic[`VECTOR_LANES - 1:0][7:0]   mx2_add_exponent,
	output logic[`VECTOR_LANES - 1:0]        mx2_guard,
	output logic[`VECTOR_LANES - 1:0]        mx2_round,
	output logic[`VECTOR_LANES - 1:0]        mx2_sticky,
	
	// Floating point multiplication
	output logic[`VECTOR_LANES - 1:0][63:0]  mx2_significand_product,
	output logic[`VECTOR_LANES - 1:0][7:0]   mx2_mul_exponent,
	output logic[`VECTOR_LANES - 1:0]        mx2_mul_sign);

	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic_gen
			scalar_t aligned_significand;
			logic guard;
			logic round;
			logic[24:0] sticky_bits;
			logic sticky;
			
			assign { aligned_significand, guard, round, sticky_bits } = { mx1_significand_se[lane_idx], 27'd0 } >> 
				mx1_se_align_shift[lane_idx];
			assign sticky = |sticky_bits;
		
			always_ff @(posedge clk)
			begin
				mx2_significand_le[lane_idx] <= mx1_significand_le[lane_idx];
				mx2_significand_se[lane_idx] <= aligned_significand;
				mx2_add_exponent[lane_idx] <= mx1_add_exponent[lane_idx];
				mx2_logical_subtract[lane_idx] <= mx1_logical_subtract[lane_idx];
				mx2_add_result_sign[lane_idx] <= mx1_add_result_sign[lane_idx];
				mx2_guard[lane_idx] <= guard;
				mx2_round[lane_idx] <= round;
				mx2_sticky[lane_idx] <= sticky;
				mx2_mul_exponent[lane_idx] <= mx1_mul_exponent[lane_idx];
				mx2_mul_sign[lane_idx] <= mx1_mul_sign[lane_idx];
				mx2_result_is_inf[lane_idx] <= mx1_result_is_inf[lane_idx];
				mx2_result_is_nan[lane_idx] <= mx1_result_is_nan[lane_idx];
				
				// XXX Simple version. Should have a wallace tree here to collect partial products.
				mx2_significand_product[lane_idx] <= mx1_multiplicand[lane_idx] * mx1_multiplier[lane_idx];
			end
		end
	endgenerate
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			mx2_instruction <= 1'h0;
			mx2_instruction_valid <= 1'h0;
			mx2_mask_value <= 1'h0;
			mx2_subcycle <= 1'h0;
			mx2_thread_idx <= 1'h0;
			// End of automatics
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
