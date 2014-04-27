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
// Floating point addition/multiplication
// - Normalization shift and rounding
// 

module multi_cycle_execute_stage5(
	input                             clk,
	input                             reset,
	
	// From mx4 stage
	input [`VECTOR_LANES - 1:0]       mx4_mask_value,
	input                             mx4_instruction_valid,
	input decoded_instruction_t       mx4_instruction,
	input thread_idx_t                mx4_thread_idx,
	input subcycle_t                  mx4_subcycle,
	
	// Addition pipeline
	input [4:0][`VECTOR_LANES - 1:0]  mx4_norm_shift,
	input [7:0][`VECTOR_LANES - 1:0]  mx4_exponent,
	input [23:0][`VECTOR_LANES - 1:0] mx4_significand,
	input [`VECTOR_LANES - 1:0]       mx4_result_sign,
	input [`VECTOR_LANES - 1:0]       mx4_logical_subtract,
	
	// To writeback stage
	output                            mx5_instruction_valid,
	output decoded_instruction_t      mx5_instruction,
	output [`VECTOR_LANES - 1:0]      mx5_mask_value,
	output thread_idx_t               mx5_thread_idx,
	output subcycle_t                 mx5_subcycle,
	output vector_t                   mx5_result);

	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic
			logic[22:0] result_significand;
			logic[7:0] result_exponent;

			always_comb
			begin
				// Normalization is only required for logical subtract operations.
				if (mx4_logical_subtract)
					result_significand = mx4_significand[lane_idx] << mx4_norm_shift[lane_idx];
				else
					result_significand = mx4_significand[lane_idx];
			end

			assign result_exponent = mx4_exponent[lane_idx] - mx4_norm_shift[lane_idx];
			always @(posedge clk)
			begin
				mx5_result[lane_idx] <= { mx4_result_sign, result_exponent, result_significand };
			end
		end
	endgenerate
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			mx5_instruction <= 0;
			mx5_instruction_valid <= 0;
			mx5_mask_value <= 0;
			mx5_thread_idx <= 0;
			mx5_subcycle <= 0;
			mx5_result <= 0;
		end
		else
		begin
			mx5_instruction <= mx5_instruction;
			mx5_instruction_valid <= mx5_instruction_valid;
			mx5_mask_value <= mx4_mask_value;
			mx5_thread_idx <= mx4_thread_idx;
			mx5_subcycle <= mx4_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
