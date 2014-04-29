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
// - Determine which operand is larger (absolute value)
// - Swap so the larger operand is first
// - Compute shift amount
//

module multi_cycle_execute_stage1(
	input                                          clk,
	input                                          reset,

	// From writeback stage                        
	input logic                                    wb_rollback_en,
	input thread_idx_t                             wb_rollback_thread_idx,
	                                               
	// From operand fetch stage                    
	input vector_t                                 of_operand1,
	input vector_t                                 of_operand2,
	input [`VECTOR_LANES - 1:0]                    of_mask_value,
	input                                          of_instruction_valid,
	input decoded_instruction_t                    of_instruction,
	input thread_idx_t                             of_thread_idx,
	input subcycle_t                               of_subcycle,
	                                               
	// To mx2 stage                                
	output                                         mx1_instruction_valid,
	output decoded_instruction_t                   mx1_instruction,
	output [`VECTOR_LANES - 1:0]                   mx1_mask_value,
	output thread_idx_t                            mx1_thread_idx,
	output subcycle_t                              mx1_subcycle,
	                                               
	// Floating point addition pipeline                    
	output logic[`VECTOR_LANES - 1:0][23:0]        mx1_significand1,
	output logic[`VECTOR_LANES - 1:0][23:0]        mx1_significand2,
	output logic[`VECTOR_LANES - 1:0][4:0]         mx1_shift_amount,
	output logic[`VECTOR_LANES - 1:0][7:0]         mx1_exponent,
	output logic[`VECTOR_LANES - 1:0]              mx1_logical_subtract,
	output logic[`VECTOR_LANES - 1:0]              mx1_result_sign);
	
	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic
			ieee754_binary32 fop1;
			ieee754_binary32 fop2;
			logic[23:0] full_significand1;
			logic[23:0] full_significand2;
			logic op1_hidden_bit;
			logic op2_hidden_bit;
			logic need_swap;
			logic[7:0] exp_difference;

			assign fop1 = of_operand1[lane_idx];
			assign fop2 = of_operand2[lane_idx];
			assign op1_hidden_bit = fop1.exponent != 0;	// Check for subnormal numbers
			assign op2_hidden_bit = fop2.exponent != 0;
			assign full_significand1 = { op1_hidden_bit, fop1.significand };
			assign full_significand2 = { op2_hidden_bit, fop2.significand };
			assign is_subtract = of_instruction.alu_op == OP_FSUB;

			// Subtle: In the case where values are equal, don't swap.  This properly handles the
			// sign for +/- zero.
			assign need_swap = fop1.exponent < fop2.exponent 
					|| (fop1.exponent == fop2.exponent && full_significand1 < full_significand2);
			assign exp_difference = need_swap ? fop2.exponent - fop1.exponent : 
				fop1.exponent - fop2.exponent;
			
			// Addition pipeline. Swap if necessary operand1 has the larger absolute value.
			always @(posedge clk)
			begin
				if (need_swap)
				begin
					// Swap
					mx1_significand1[lane_idx] <= full_significand2;
					mx1_significand2[lane_idx] <= full_significand1;
					mx1_exponent[lane_idx] <= fop2.exponent;
					mx1_result_sign[lane_idx] <= fop2.sign ^ is_subtract;
				end
				else
				begin
					// Don't swap.
					mx1_significand1[lane_idx] <= full_significand1;
					mx1_significand2[lane_idx] <= full_significand2;
					mx1_exponent[lane_idx] <= fop1.exponent;
					mx1_result_sign[lane_idx] <= fop1.sign;	// Larger magnitude sign wins
				end

				mx1_logical_subtract[lane_idx] <= fop1.sign ^ fop2.sign ^ is_subtract;
				
				// Note that we shift up to 27 bits, even though the significand is only
				// 24 bits.  This allows shifting out the guard and round bits.
				mx1_shift_amount[lane_idx] <= exp_difference < 27 ? exp_difference : 27;	
			end
		end
	endgenerate
	
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
			mx1_instruction_valid <= of_instruction_valid && (!wb_rollback_en || wb_rollback_thread_idx != of_thread_idx)
				&& of_instruction.pipeline_sel == PIPE_MCYCLE_ARITH;
			mx1_instruction <= of_instruction;
			mx1_mask_value <= of_mask_value;
			mx1_thread_idx <= of_thread_idx;
			mx1_subcycle <= of_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
