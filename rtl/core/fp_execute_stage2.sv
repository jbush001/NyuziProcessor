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
// Floating Point Execute Stage 2
//
// Floating Point Addition
// - Shift smaller operand to align with larger
// Floating Point multiplication
// - Perform actual operation (XXX placeholder, see below)
// Float to int conversion
// - Shift significand right to truncate fractional bit positions
//

module fp_execute_stage2(
	input                                    clk,
	input                                    reset,
                                            
	// From writeback stage                 
	input logic                              wb_rollback_en,
	input thread_idx_t                       wb_rollback_thread_idx,
	input pipeline_sel_t                     wb_rollback_pipeline,
	                                        
	// From mx1 stage                       
	input vector_lane_mask_t                 fx1_mask_value,
	input                                    fx1_instruction_valid,
	input decoded_instruction_t              fx1_instruction,
	input thread_idx_t                       fx1_thread_idx,
	input subcycle_t                         fx1_subcycle,
	input [`VECTOR_LANES - 1:0]              fx1_result_is_inf,
	input [`VECTOR_LANES - 1:0]              fx1_result_is_nan,
	input [`VECTOR_LANES - 1:0][5:0]         fx1_ftoi_lshift,
                                            
	// Floating point addition/subtraction                    
	input scalar_t[`VECTOR_LANES - 1:0]      fx1_significand_le,
	input scalar_t[`VECTOR_LANES - 1:0]      fx1_significand_se,
	input [`VECTOR_LANES - 1:0]              fx1_logical_subtract,
	input [`VECTOR_LANES - 1:0][5:0]         fx1_se_align_shift,
	input [`VECTOR_LANES - 1:0][7:0]         fx1_add_exponent,
	input [`VECTOR_LANES - 1:0]              fx1_add_result_sign,

	// Floating point multiplication
	input [`VECTOR_LANES - 1:0][7:0]         fx1_mul_exponent,
	input [`VECTOR_LANES - 1:0]              fx1_mul_sign,
	input [`VECTOR_LANES - 1:0][31:0]        fx1_multiplicand,
	input [`VECTOR_LANES - 1:0][31:0]        fx1_multiplier,
	                                        
	// To mx3 stage                         
	output                                   fx2_instruction_valid,
	output decoded_instruction_t             fx2_instruction,
	output vector_lane_mask_t                fx2_mask_value,
	output thread_idx_t                      fx2_thread_idx,
	output subcycle_t                        fx2_subcycle,
	output logic[`VECTOR_LANES - 1:0]        fx2_result_is_inf,
	output logic[`VECTOR_LANES - 1:0]        fx2_result_is_nan,
	output logic[`VECTOR_LANES - 1:0][5:0]   fx2_ftoi_lshift,
	
	// Floating point addition/subtraction                    
	output logic[`VECTOR_LANES - 1:0]        fx2_logical_subtract,
	output logic[`VECTOR_LANES - 1:0]        fx2_add_result_sign,
	output scalar_t[`VECTOR_LANES - 1:0]     fx2_significand_le,
	output scalar_t[`VECTOR_LANES - 1:0]     fx2_significand_se,
	output logic[`VECTOR_LANES - 1:0][7:0]   fx2_add_exponent,
	output logic[`VECTOR_LANES - 1:0]        fx2_guard,
	output logic[`VECTOR_LANES - 1:0]        fx2_round,
	output logic[`VECTOR_LANES - 1:0]        fx2_sticky,
	
	// Floating point multiplication
	output logic[`VECTOR_LANES - 1:0][63:0]  fx2_significand_product,
	output logic[`VECTOR_LANES - 1:0][7:0]   fx2_mul_exponent,
	output logic[`VECTOR_LANES - 1:0]        fx2_mul_sign);

	logic is_imulhs;
	
	assign is_imulhs = fx1_instruction.alu_op == OP_MULH_I;

	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic_gen
			scalar_t aligned_significand;
			logic guard;
			logic round;
			logic[24:0] sticky_bits;
			logic sticky;
			logic[63:0] sext_multiplicand;
			logic[63:0] sext_multiplier;
			
			assign { aligned_significand, guard, round, sticky_bits } = { fx1_significand_se[lane_idx], 27'd0 } >> 
				fx1_se_align_shift[lane_idx];
			assign sticky = |sticky_bits;

			// Sign extend multiply operands
			assign sext_multiplicand = { {32{fx1_multiplicand[lane_idx][31] && is_imulhs }}, 
				fx1_multiplicand[lane_idx] };
			assign sext_multiplier = { {32{fx1_multiplier[lane_idx][31] && is_imulhs }}, 
				fx1_multiplier[lane_idx] };
		
			always_ff @(posedge clk)
			begin
				fx2_significand_le[lane_idx] <= fx1_significand_le[lane_idx];
				fx2_significand_se[lane_idx] <= aligned_significand;
				fx2_add_exponent[lane_idx] <= fx1_add_exponent[lane_idx];
				fx2_logical_subtract[lane_idx] <= fx1_logical_subtract[lane_idx];
				fx2_add_result_sign[lane_idx] <= fx1_add_result_sign[lane_idx];
				fx2_guard[lane_idx] <= guard;
				fx2_round[lane_idx] <= round;
				fx2_sticky[lane_idx] <= sticky;
				fx2_mul_exponent[lane_idx] <= fx1_mul_exponent[lane_idx];
				fx2_mul_sign[lane_idx] <= fx1_mul_sign[lane_idx];
				fx2_result_is_inf[lane_idx] <= fx1_result_is_inf[lane_idx];
				fx2_result_is_nan[lane_idx] <= fx1_result_is_nan[lane_idx];
				fx2_ftoi_lshift[lane_idx] <= fx1_ftoi_lshift[lane_idx];
				
				// XXX Simple version. Should have a wallace tree here to collect partial products.
				fx2_significand_product[lane_idx] <= sext_multiplicand * sext_multiplier;
			end
		end
	endgenerate
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			fx2_instruction <= 1'h0;
			fx2_instruction_valid <= 1'h0;
			fx2_mask_value <= 1'h0;
			fx2_subcycle <= 1'h0;
			fx2_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			fx2_instruction <= fx1_instruction;
			fx2_instruction_valid <= fx1_instruction_valid && (!wb_rollback_en || wb_rollback_thread_idx != fx1_thread_idx
				|| wb_rollback_pipeline != PIPE_MEM);
			fx2_mask_value <= fx1_mask_value;
			fx2_thread_idx <= fx1_thread_idx;
			fx2_subcycle <= fx1_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
