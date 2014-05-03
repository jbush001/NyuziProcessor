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
// - Add/subtract significands
// - Rounding for subtraction
//

module multi_cycle_execute_stage3(
	input                                    clk,
	input                                    reset,
	                                        
	// From mx2 stage                       
	input [`VECTOR_LANES - 1:0]              mx2_mask_value,
	input                                    mx2_instruction_valid,
	input decoded_instruction_t              mx2_instruction,
	input thread_idx_t                       mx2_thread_idx,
	input subcycle_t                         mx2_subcycle,
	input [`VECTOR_LANES - 1:0]              mx2_result_is_inf,
	input [`VECTOR_LANES - 1:0]              mx2_result_is_nan,
	
	// Floating point addition/subtraction                    
	input[`VECTOR_LANES - 1:0][23:0]         mx2_significand_le,
	input[`VECTOR_LANES - 1:0][23:0]         mx2_significand_se,
	input[`VECTOR_LANES - 1:0]               mx2_logical_subtract,
	input[`VECTOR_LANES - 1:0][7:0]          mx2_add_exponent,
	input[`VECTOR_LANES - 1:0]               mx2_add_result_sign,
	input[`VECTOR_LANES - 1:0]               mx2_guard,
	input[`VECTOR_LANES - 1:0]               mx2_round,
	input[`VECTOR_LANES - 1:0]               mx2_sticky,

	// Floating point multiplication
	input [`VECTOR_LANES - 1:0][47:0]        mx2_significand_product,
	input [`VECTOR_LANES - 1:0][7:0]         mx2_mul_exponent,
	input [`VECTOR_LANES - 1:0]              mx2_mul_sign,
	
	// To mx4 stage
	output logic                             mx3_instruction_valid,
	output decoded_instruction_t             mx3_instruction,
	output logic[`VECTOR_LANES - 1:0]        mx3_mask_value,
	output thread_idx_t                      mx3_thread_idx,
	output subcycle_t                        mx3_subcycle,
	output logic[`VECTOR_LANES - 1:0]        mx3_result_is_inf,
	output logic[`VECTOR_LANES - 1:0]        mx3_result_is_nan,
	
	// Floating point addition/subtraction                    
	output logic[`VECTOR_LANES - 1:0][24:0]  mx3_sum,
	output logic[`VECTOR_LANES - 1:0][7:0]   mx3_add_exponent,
	output logic[`VECTOR_LANES - 1:0]        mx3_add_result_sign,
	output logic[`VECTOR_LANES - 1:0]        mx3_logical_subtract,
	
	// Floating point multiplication
	output logic[`VECTOR_LANES - 1:0][47:0]  mx3_significand_product,
	output logic[`VECTOR_LANES - 1:0][7:0]   mx3_mul_exponent,
	output logic[`VECTOR_LANES - 1:0]        mx3_mul_sign);

	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic
			logic carry_in;
			logic[25:0] unnormalized_sum;
			
			// For logical subtraction, rounding reduces the unnormalized sum because it rounds the
			// subtrahend up.  Since we are inverting the second parameter to perform a subtraction,
			// a +1 is normally necessary. For logical addition, rounding increases the unnormalized
			// sum.  We can accomplish both by setting carry_in appropriately.
			assign carry_in = mx2_logical_subtract[lane_idx] ^ (mx2_guard[lane_idx] && (mx2_round[lane_idx] 
				|| mx2_sticky[lane_idx]));
			assign unnormalized_sum = { mx2_significand_le[lane_idx], 1'b1 } 
				+ { (mx2_significand_se[lane_idx] ^ {25{mx2_logical_subtract[lane_idx]}}), carry_in };

			always @(posedge clk)
			begin
				mx3_result_is_inf[lane_idx] <= mx2_result_is_inf[lane_idx];
				mx3_result_is_nan[lane_idx] <= mx2_result_is_nan[lane_idx];

				// Addition
				mx3_sum[lane_idx] <= unnormalized_sum[25:1];
				mx3_add_exponent[lane_idx] <= mx2_add_exponent[lane_idx];
				mx3_logical_subtract[lane_idx] <= mx2_logical_subtract[lane_idx];
				mx3_add_result_sign[lane_idx] <= mx2_add_result_sign[lane_idx];

				// Multiplication
				mx3_significand_product[lane_idx] <= mx2_significand_product[lane_idx];
				mx3_mul_exponent[lane_idx] <= mx2_mul_exponent[lane_idx];
				mx3_mul_sign[lane_idx] <= mx2_mul_sign[lane_idx];
			end
		end
	endgenerate
	
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
