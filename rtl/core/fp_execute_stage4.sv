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
// Floating Point Execute Stage 4
//
// Floating point addition/multiplication
// - Leading zero detection to determine normalization shift amount for addition
// - Multiplication result is pass through.  Could have second stage of wallace tree here.
// 

module fp_execute_stage4(
	input                                    clk,
	input                                    reset,
	                                        
	// From mx3 stage                       
	input vector_lane_mask_t                 fx3_mask_value,
	input                                    fx3_instruction_valid,
	input decoded_instruction_t              fx3_instruction,
	input thread_idx_t                       fx3_thread_idx,
	input subcycle_t                         fx3_subcycle,
	input [`VECTOR_LANES - 1:0]              fx3_result_is_inf,
	input [`VECTOR_LANES - 1:0]              fx3_result_is_nan,
	                                        
	// Floating point addition/subtraction                    
	input scalar_t[`VECTOR_LANES - 1:0]      fx3_add_significand,
	input[`VECTOR_LANES - 1:0][7:0]          fx3_add_exponent,
	input[`VECTOR_LANES - 1:0]               fx3_add_result_sign,
	input[`VECTOR_LANES - 1:0]               fx3_logical_subtract,

	// Floating point multiplication
	input [`VECTOR_LANES - 1:0][63:0]        fx3_significand_product,
	input [`VECTOR_LANES - 1:0][7:0]         fx3_mul_exponent,
	input [`VECTOR_LANES - 1:0]              fx3_mul_sign,
	                                        
	// To mx4 stage                         
	output                                   fx4_instruction_valid,
	output decoded_instruction_t             fx4_instruction,
	output vector_lane_mask_t                fx4_mask_value,
	output thread_idx_t                      fx4_thread_idx,
	output subcycle_t                        fx4_subcycle,
	output logic [`VECTOR_LANES - 1:0]       fx4_result_is_inf,
	output logic [`VECTOR_LANES - 1:0]       fx4_result_is_nan,
	
	// Floating point addition/subtraction                    
	output logic[`VECTOR_LANES - 1:0][7:0]   fx4_add_exponent,
	output logic[`VECTOR_LANES - 1:0][31:0]  fx4_add_significand,
	output logic[`VECTOR_LANES - 1:0]        fx4_add_result_sign,
	output logic[`VECTOR_LANES - 1:0]        fx4_logical_subtract,
	output logic[`VECTOR_LANES - 1:0][5:0]   fx4_norm_shift,
	
	// Floating point multiplication
	output logic[`VECTOR_LANES - 1:0][63:0]  fx4_significand_product,
	output logic[`VECTOR_LANES - 1:0][7:0]   fx4_mul_exponent,
	output logic[`VECTOR_LANES - 1:0]        fx4_mul_sign);
	
	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic_gen
			int leading_zeroes;
			logic[24:0] significand_from_mx3;
			logic[5:0] norm_shift_nxt;
			
			// Leading zero detection: determine normalization shift amount for add/sub.
			always_comb
			begin
				// That the 24th and 0th bit positions will get chopped already.  The
				// normalization shift measures how far the value needs to be shifted to 
				// make the leading one be truncated.
				norm_shift_nxt = 0;
				casez (fx3_add_significand[lane_idx])	
					32'b1???????????????????????????????: norm_shift_nxt = 0;
					32'b01??????????????????????????????: norm_shift_nxt = 1;
					32'b001?????????????????????????????: norm_shift_nxt = 2;
					32'b0001????????????????????????????: norm_shift_nxt = 3;
					32'b00001???????????????????????????: norm_shift_nxt = 4;
					32'b000001??????????????????????????: norm_shift_nxt = 5;
					32'b0000001?????????????????????????: norm_shift_nxt = 6;
					32'b00000001????????????????????????: norm_shift_nxt = 7;
					32'b000000001???????????????????????: norm_shift_nxt = 8;
					32'b0000000001??????????????????????: norm_shift_nxt = 9;
					32'b00000000001?????????????????????: norm_shift_nxt = 10;
					32'b000000000001????????????????????: norm_shift_nxt = 11;
					32'b0000000000001???????????????????: norm_shift_nxt = 12;
					32'b00000000000001??????????????????: norm_shift_nxt = 13;
					32'b000000000000001?????????????????: norm_shift_nxt = 14;
					32'b0000000000000001????????????????: norm_shift_nxt = 15;
					32'b00000000000000001???????????????: norm_shift_nxt = 16;
					32'b000000000000000001??????????????: norm_shift_nxt = 17;
					32'b0000000000000000001?????????????: norm_shift_nxt = 18;
					32'b00000000000000000001????????????: norm_shift_nxt = 19;
					32'b000000000000000000001???????????: norm_shift_nxt = 20;
					32'b0000000000000000000001??????????: norm_shift_nxt = 21;
					32'b00000000000000000000001?????????: norm_shift_nxt = 22;
					32'b000000000000000000000001????????: norm_shift_nxt = 23;
					32'b0000000000000000000000001???????: norm_shift_nxt = 24;
					32'b00000000000000000000000001??????: norm_shift_nxt = 25;
					32'b000000000000000000000000001?????: norm_shift_nxt = 26;
					32'b0000000000000000000000000001????: norm_shift_nxt = 27;
					32'b00000000000000000000000000001???: norm_shift_nxt = 28;
					32'b000000000000000000000000000001??: norm_shift_nxt = 29;
					32'b0000000000000000000000000000001?: norm_shift_nxt = 30;
					32'b00000000000000000000000000000001: norm_shift_nxt = 31;
					32'b00000000000000000000000000000000: norm_shift_nxt = 32;
					default: norm_shift_nxt = 0;
				endcase
			end
			
			always_ff @(posedge clk)
			begin
				fx4_add_significand[lane_idx] <= fx3_add_significand[lane_idx];
				fx4_norm_shift[lane_idx] <= norm_shift_nxt;
				fx4_add_exponent[lane_idx] <= fx3_add_exponent[lane_idx];
				fx4_add_result_sign[lane_idx] <= fx3_add_result_sign[lane_idx];
				fx4_logical_subtract[lane_idx] <= fx3_logical_subtract[lane_idx];
				fx4_significand_product[lane_idx] <= fx3_significand_product[lane_idx];
				fx4_mul_exponent[lane_idx] <= fx3_mul_exponent[lane_idx];
				fx4_mul_sign[lane_idx] <= fx3_mul_sign[lane_idx];
				fx4_result_is_inf[lane_idx] <= fx3_result_is_inf[lane_idx];
				fx4_result_is_nan[lane_idx] <= fx3_result_is_nan[lane_idx];
			end
		end
	endgenerate
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			fx4_instruction <= 1'h0;
			fx4_instruction_valid <= 1'h0;
			fx4_mask_value <= 1'h0;
			fx4_subcycle <= 1'h0;
			fx4_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			fx4_instruction <= fx3_instruction;
			fx4_instruction_valid <= fx3_instruction_valid;
			fx4_mask_value <= fx3_mask_value;
			fx4_thread_idx <= fx3_thread_idx;
			fx4_subcycle <= fx3_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
