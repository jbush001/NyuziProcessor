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
// Multicycle execution pipeline stage 5
//
// Floating point addition/multiplication
// - Normalization shift
// - Post normal rounding (for addition overflow)
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
	input [`VECTOR_LANES - 1:0][63:0]   mx4_significand_product,
	input [`VECTOR_LANES - 1:0][7:0]    mx4_mul_exponent,
	input [`VECTOR_LANES - 1:0]         mx4_mul_sign,
	                                    
	// To writeback stage               
	output                              mx5_instruction_valid,
	output decoded_instruction_t        mx5_instruction,
	output [`VECTOR_LANES - 1:0]        mx5_mask_value,
	output thread_idx_t                 mx5_thread_idx,
	output subcycle_t                   mx5_subcycle,
	output vector_t                     mx5_result);

	logic is_fmul;
	logic is_imul;
	logic is_ftoi;

	assign is_fmul = mx4_instruction.alu_op == OP_FMUL;
	assign is_imul = mx4_instruction.alu_op == OP_IMUL;
	assign is_ftoi = mx4_instruction.alu_op == OP_FTOI;

	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic_gen
			logic[22:0] add_result_significand;
			logic[7:0] add_result_exponent;
			logic[7:0] adjusted_add_exponent;
			scalar_t shifted_significand;
			logic add_is_subnormal;
			scalar_t add_result;
			logic add_round;
			logic mul_normalize_shift;
			logic[22:0] mul_normalized_significand;
			logic[22:0] mul_rounded_significand;
			scalar_t fmul_result;
			logic[7:0] mul_exponent;
			logic mul_guard;
			logic mul_round;
			logic[21:0] mul_sticky_bits;
			logic mul_sticky;
			logic mul_round_tie;
			logic mul_round_up;
			logic mul_do_round;
			logic mul_is_subnormal;
			logic compare_result;
			logic sum_is_zero;
			logic mul_hidden_bit;
			logic mul_round_overflow;

			assign adjusted_add_exponent = mx4_add_exponent[lane_idx] - mx4_norm_shift[lane_idx] + 8;
			assign add_is_subnormal = mx4_add_exponent[lane_idx] == 0 || mx4_add_significand[lane_idx] == 0;
			assign shifted_significand = mx4_add_significand[lane_idx] << mx4_norm_shift[lane_idx];

			// Because only one bit can be shifted out, we can only round to even here.  
			// shifted_significand[7] is the guard bit.  shifted_significand[8] indicates whether
			// the result is even or odd.
			assign add_round = shifted_significand[7] && shifted_significand[8] && !mx4_logical_subtract[lane_idx];
			assign add_result_significand = add_is_subnormal ? mx4_add_significand[lane_idx][22:0] 
				: (shifted_significand[30:8] + add_round);	// Round up using truncated bit
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

			// Note that, if the operation is unordered (either operand is NaN), we treat the result as false
			always_comb
			begin
				compare_result = 0;
				case (mx4_instruction.alu_op)
					OP_FGTR: compare_result = !mx4_add_result_sign[lane_idx] && !sum_is_zero && !mx4_result_is_nan[lane_idx];
					OP_FGTE: compare_result = (!mx4_add_result_sign[lane_idx] || sum_is_zero) && !mx4_result_is_nan[lane_idx];
					OP_FLT: compare_result = mx4_add_result_sign[lane_idx] && !sum_is_zero && !mx4_result_is_nan[lane_idx];
					OP_FLTE: compare_result = (mx4_add_result_sign[lane_idx] || sum_is_zero) && !mx4_result_is_nan[lane_idx];
				endcase
			end

			// If the operands for multiplication are both normalized (start with a leading 1), then the 
			// the maximum normalization shift is one place.  
			// XXX does not handle subnormal product
			assign mul_normalize_shift = !mx4_significand_product[lane_idx][47];
			assign { mul_normalized_significand, mul_guard, mul_round, mul_sticky_bits } = mul_normalize_shift 
				? { mx4_significand_product[lane_idx][45:0], 1'b0 }
				: mx4_significand_product[lane_idx][46:0];
			assign mul_sticky = |mul_sticky_bits;
			assign mul_round_tie = mul_guard && !(mul_round || mul_sticky);
			assign mul_round_up = mul_guard && (mul_round || mul_sticky);
			assign mul_do_round = mul_round_up || (mul_round_tie && mul_normalized_significand[0]);
			assign mul_rounded_significand = mul_normalized_significand + mul_do_round;
			assign mul_hidden_bit = mul_normalize_shift ? mx4_significand_product[lane_idx][46] : 1'b1;
			assign mul_round_overflow = mul_do_round && mul_rounded_significand == 0;
			always_comb
			begin
				if (!mul_hidden_bit)
					mul_exponent = 0;	// Is subnormal
				else if (mul_normalize_shift && !mul_round_overflow)
					mul_exponent = mx4_mul_exponent[lane_idx];
				else
					mul_exponent = mx4_mul_exponent[lane_idx] + 1;			
			end
			
			always_comb
			begin
				if (mx4_result_is_inf[lane_idx])
					fmul_result = { mx4_mul_sign[lane_idx], 8'hff, 23'd0 };
				else if (mx4_result_is_nan[lane_idx])
					fmul_result = { 32'h7fffffff };
				else
					fmul_result = { mx4_mul_sign[lane_idx], mul_exponent, mul_rounded_significand };
			end

			always_ff @(posedge clk)
			begin
				if (is_ftoi)
				begin
					if (mx4_result_is_nan[lane_idx])
						mx5_result[lane_idx] <= 32'h80000000;	// nan signal indicates an invalid conversion
					else
						mx5_result[lane_idx] <= mx4_add_significand[lane_idx];
				end
				else if (mx4_instruction.is_compare)
					mx5_result[lane_idx] <= compare_result;
				else if (is_imul)
					mx5_result[lane_idx] <= mx4_significand_product[lane_idx][31:0];
				else if (is_fmul)
					mx5_result[lane_idx] <= fmul_result;
				else
					mx5_result[lane_idx] <= add_result;
			end
		end
	endgenerate
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			mx5_instruction <= 1'h0;
			mx5_instruction_valid <= 1'h0;
			mx5_mask_value <= {(1+(`VECTOR_LANES-1)){1'b0}};
			mx5_subcycle <= 1'h0;
			mx5_thread_idx <= 1'h0;
			// End of automatics
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
