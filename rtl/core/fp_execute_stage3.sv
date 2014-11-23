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
// Floating Point Execute Stage 3
//
// Floating Point Addition
// - Add/subtract significands
// - Rounding for subtraction
// Int-to-float/float-to-int
// - Convert negative values to 2s complement.
// Floating point multiplication
// - pass through
//

module fp_execute_stage3(
	input                                    clk,
	input                                    reset,
	                                        
	// From mx2 stage                       
	input vector_lane_mask_t                 fx2_mask_value,
	input                                    fx2_instruction_valid,
	input decoded_instruction_t              fx2_instruction,
	input thread_idx_t                       fx2_thread_idx,
	input subcycle_t                         fx2_subcycle,
	input [`VECTOR_LANES - 1:0]              fx2_result_is_inf,
	input [`VECTOR_LANES - 1:0]              fx2_result_is_nan,
	input [`VECTOR_LANES - 1:0][5:0]         fx2_ftoi_lshift,
	
	// Floating point addition/subtraction                    
	input scalar_t[`VECTOR_LANES - 1:0]      fx2_significand_le,
	input scalar_t[`VECTOR_LANES - 1:0]      fx2_significand_se,
	input[`VECTOR_LANES - 1:0]               fx2_logical_subtract,
	input[`VECTOR_LANES - 1:0][7:0]          fx2_add_exponent,
	input[`VECTOR_LANES - 1:0]               fx2_add_result_sign,
	input[`VECTOR_LANES - 1:0]               fx2_guard,
	input[`VECTOR_LANES - 1:0]               fx2_round,
	input[`VECTOR_LANES - 1:0]               fx2_sticky,

	// Floating point multiplication
	input [`VECTOR_LANES - 1:0][63:0]        fx2_significand_product,
	input [`VECTOR_LANES - 1:0][7:0]         fx2_mul_exponent,
	input [`VECTOR_LANES - 1:0]              fx2_mul_sign,
	
	// To mx4 stage
	output logic                             fx3_instruction_valid,
	output decoded_instruction_t             fx3_instruction,
	output vector_lane_mask_t                fx3_mask_value,
	output thread_idx_t                      fx3_thread_idx,
	output subcycle_t                        fx3_subcycle,
	output logic[`VECTOR_LANES - 1:0]        fx3_result_is_inf,
	output logic[`VECTOR_LANES - 1:0]        fx3_result_is_nan,
	output logic[`VECTOR_LANES - 1:0][5:0]   fx3_ftoi_lshift,
	
	// Floating point addition/subtraction                    
	output scalar_t[`VECTOR_LANES - 1:0]     fx3_add_significand,
	output logic[`VECTOR_LANES - 1:0][7:0]   fx3_add_exponent,
	output logic[`VECTOR_LANES - 1:0]        fx3_add_result_sign,
	output logic[`VECTOR_LANES - 1:0]        fx3_logical_subtract,
	
	// Floating point multiplication
	output logic[`VECTOR_LANES - 1:0][63:0]  fx3_significand_product,
	output logic[`VECTOR_LANES - 1:0][7:0]   fx3_mul_exponent,
	output logic[`VECTOR_LANES - 1:0]        fx3_mul_sign);

	logic is_ftoi;

	assign is_ftoi = fx2_instruction.alu_op == OP_FTOI;

	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic_gen
			logic carry_in;
			scalar_t unnormalized_sum;
			logic sum_is_odd;
			logic round_up;
			logic round_tie;
			logic do_round;
			logic _ignore;

			// Round-to-nearest, round half to even.  We first compute the value of only the low
			// bit of the sum independently here to predict if the result is odd.
			assign sum_is_odd = fx2_significand_le[lane_idx][0] ^ fx2_significand_se[lane_idx][0];
			assign round_tie = (fx2_guard[lane_idx] && !(fx2_round[lane_idx] || fx2_sticky[lane_idx]));
			assign round_up = (fx2_guard[lane_idx] && (fx2_round[lane_idx] || fx2_sticky[lane_idx]));
			assign do_round = (round_up || (sum_is_odd && round_tie));
			
			// For logical subtraction, rounding reduces the unnormalized sum because it rounds the
			// subtrahend up.  Since we are inverting the second parameter to perform a subtraction,
			// a +1 is normally necessary. We round down by not doing that. For logical addition, rounding 
			// increases the unnormalized sum.  We can accomplish either of these by setting carry_in 
			// appropriately.
			//
			// For float<->int conversions, we overload this to handle changing between signed-magnitude
			// and two's complement format.  LE is set to zero and fx2_logical_subtract indicates
			// if it needs a conversion.
			assign carry_in = fx2_logical_subtract[lane_idx] ^ (do_round && !is_ftoi);
			assign { unnormalized_sum, _ignore } = { fx2_significand_le[lane_idx], 1'b1 } 
				+ { (fx2_significand_se[lane_idx] ^ {32{fx2_logical_subtract[lane_idx]}}), carry_in };

			always_ff @(posedge clk)
			begin
				fx3_result_is_inf[lane_idx] <= fx2_result_is_inf[lane_idx];
				fx3_result_is_nan[lane_idx] <= fx2_result_is_nan[lane_idx];
				fx3_ftoi_lshift[lane_idx] <= fx2_ftoi_lshift[lane_idx];

				// Addition
				fx3_add_significand[lane_idx] <= unnormalized_sum;
				fx3_add_exponent[lane_idx] <= fx2_add_exponent[lane_idx];
				fx3_logical_subtract[lane_idx] <= fx2_logical_subtract[lane_idx];
				fx3_add_result_sign[lane_idx] <= fx2_add_result_sign[lane_idx];

				// Multiplication
				fx3_significand_product[lane_idx] <= fx2_significand_product[lane_idx];
				fx3_mul_exponent[lane_idx] <= fx2_mul_exponent[lane_idx];
				fx3_mul_sign[lane_idx] <= fx2_mul_sign[lane_idx];
			end
		end
	endgenerate
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			fx3_instruction <= 1'h0;
			fx3_instruction_valid <= 1'h0;
			fx3_mask_value <= 1'h0;
			fx3_subcycle <= 1'h0;
			fx3_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			fx3_instruction <= fx2_instruction;
			fx3_instruction_valid <= fx2_instruction_valid;
			fx3_mask_value <= fx2_mask_value;
			fx3_thread_idx <= fx2_thread_idx;
			fx3_subcycle <= fx2_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
