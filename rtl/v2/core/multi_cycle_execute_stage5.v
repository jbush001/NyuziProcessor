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
// - Normalization shift
// 

module multi_cycle_execute_stage5(
	input                               clk,
	input                               reset,
	                                    
	// From mx4 stage                   
	input [`VECTOR_LANES - 1:0]         mx4_mask_value,
	input                               mx4_instruction_valid,
	input decoded_instruction_t         mx4_instruction,
	input thread_idx_t                  mx4_thread_idx,
	input subcycle_t                    mx4_subcycle,
	input [`VECTOR_LANES - 1:0]         mx4_result_is_inf,
	input [`VECTOR_LANES - 1:0]         mx4_result_is_nan,
	
	// Floating point addition/subtraction                    
	input [`VECTOR_LANES - 1:0][7:0]    mx4_add_exponent,
	input scalar_t[`VECTOR_LANES - 1:0] mx4_add_significand,
	input [`VECTOR_LANES - 1:0]         mx4_add_result_sign,
	input [`VECTOR_LANES - 1:0]         mx4_logical_subtract,
	input [`VECTOR_LANES - 1:0][5:0]    mx4_norm_shift,
                                        
	// Floating point multiplication    
	input [`VECTOR_LANES - 1:0][47:0]   mx4_significand_product,
	input [`VECTOR_LANES - 1:0][7:0]    mx4_mul_exponent,
	input [`VECTOR_LANES - 1:0]         mx4_mul_sign,
	                                    
	// To writeback stage               
	output                              mx5_instruction_valid,
	output decoded_instruction_t        mx5_instruction,
	output [`VECTOR_LANES - 1:0]        mx5_mask_value,
	output thread_idx_t                 mx5_thread_idx,
	output subcycle_t                   mx5_subcycle,
	output vector_t                     mx5_result);

	logic is_mul;
	logic is_ftoi;
	logic is_itof;

	assign is_mul = mx4_instruction.alu_op == OP_FMUL;
	assign is_ftoi = mx4_instruction.alu_op == OP_FTOI;
	assign is_itof = mx4_instruction.alu_op == OP_ITOF;

	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic
			logic[22:0] add_result_significand;
			logic[7:0] add_result_exponent;
			logic[7:0] adjusted_add_exponent;
			scalar_t shifted_significand;
			logic add_is_subnormal;
			scalar_t add_result;
			logic mul_normalize_shift;
			logic[22:0] mul_normalized_significand;
			logic[22:0] mul_rounded_significand;
			scalar_t mul_result;
			logic[7:0] mul_exponent;
			logic mul_guard;
			logic mul_round;
			logic mul_sticky;
			logic mul_is_subnormal;
			logic compare_result;
			logic sum_is_zero;

			assign adjusted_add_exponent = mx4_add_exponent[lane_idx] - mx4_norm_shift[lane_idx] + 8;
			assign add_is_subnormal = mx4_add_exponent[lane_idx] == 0 || mx4_add_significand[lane_idx] == 0;
			assign shifted_significand = mx4_add_significand[lane_idx] << mx4_norm_shift[lane_idx];
			assign add_result_significand = add_is_subnormal ? mx4_add_significand[lane_idx][22:0] 
				: (shifted_significand[30:8] + shifted_significand[7]);	// Round up using truncated bit
			assign add_result_exponent = add_is_subnormal ? 0 : adjusted_add_exponent;

			always_comb
			begin
				if (mx4_result_is_inf[lane_idx])
					add_result = { mx4_add_result_sign[lane_idx], 8'hff, 23'd0 };
				else if (mx4_result_is_nan[lane_idx])
					add_result = { 32'h7fffffff };
				else if (add_result_significand == 0 && add_is_subnormal)
				begin
					// IEEE754-2008, 6.3: "When the sum of two operands with opposite signs (or the difference 
					// of two operands with like signs) is exactly zero, the sign of that sum (or difference) 
					// shall be +0.
					// XXX this will pick up some additional cases like -0.0 + 0.0."
					add_result = 0;
				end
				else
					add_result = { mx4_add_result_sign[lane_idx], add_result_exponent, add_result_significand };
			end

			assign sum_is_zero = add_is_subnormal && add_result_significand == 0;

			always_comb
			begin
				compare_result = 0;
				case (mx4_instruction.alu_op)
					OP_FGTR: compare_result = !mx4_add_result_sign[lane_idx] && !sum_is_zero;
					OP_FGTE: compare_result = !mx4_add_result_sign[lane_idx] || sum_is_zero;
					OP_FLT: compare_result = mx4_add_result_sign[lane_idx] && !sum_is_zero;
					OP_FLTE: compare_result = mx4_add_result_sign[lane_idx] || sum_is_zero;
				endcase
			end

			// If the operands for multiplication are both normalized (start with a leading 1), then there 
			// the maximum normalization shift is one place.  
			// XXX subnormal numbers
			assign mul_normalize_shift = !mx4_significand_product[lane_idx][47];
			assign mul_normalized_significand = mul_normalize_shift 
				? mx4_significand_product[lane_idx][45:23]
				: mx4_significand_product[lane_idx][46:24];
			assign { mul_guard, mul_round, mul_sticky } = mul_normalize_shift
				? { mx4_significand_product[lane_idx][22:21], |mx4_significand_product[lane_idx][20:0] }
				: { mx4_significand_product[lane_idx][23:22], |mx4_significand_product[lane_idx][21:0] };
			assign mul_rounded_significand = mul_normalized_significand + (mul_guard && (mul_round || mul_sticky));
			always_comb
			begin
				if (mul_normalized_significand == 0)
					mul_exponent = 0;	// Is subnormal
				else
					mul_exponent = mul_normalize_shift ? mx4_mul_exponent[lane_idx] : mx4_mul_exponent[lane_idx] + 1;
			end
			
			always_comb
			begin
				if (mx4_result_is_inf)
					mul_result = { mx4_mul_sign[lane_idx], 8'hff, 23'd0 };
				else if (mx4_result_is_nan)
					mul_result = { 32'h7fffffff };
				else
					mul_result = { mx4_mul_sign[lane_idx], mul_exponent, mul_rounded_significand };
			end

			always @(posedge clk)
			begin
				if (is_ftoi)
				begin
					if (mx4_result_is_nan)
						mx5_result[lane_idx] <= 32'h80000000;	// nan signal indicates an invalid conversion
					else
						mx5_result[lane_idx] <= mx4_add_significand[lane_idx];
				end
				else if (mx4_instruction.is_compare)
					mx5_result[lane_idx] <= compare_result;
				else if (is_mul)
					mx5_result[lane_idx] <= mul_result;
				else
					mx5_result[lane_idx] <= add_result;
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
		end
		else
		begin
			mx5_instruction <= mx4_instruction;
			mx5_instruction_valid <= mx4_instruction_valid;
			mx5_mask_value <= mx4_mask_value;
			mx5_thread_idx <= mx4_thread_idx;
			mx5_subcycle <= mx4_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
