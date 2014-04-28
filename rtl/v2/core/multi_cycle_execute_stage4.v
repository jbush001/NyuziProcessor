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
// - Leading zero detection to determine normalization shift amount
// 

module multi_cycle_execute_stage4(
	input                                    clk,
	input                                    reset,
	                                        
	// From mx3 stage                       
	input [`VECTOR_LANES - 1:0]              mx3_mask_value,
	input                                    mx3_instruction_valid,
	input decoded_instruction_t              mx3_instruction,
	input thread_idx_t                       mx3_thread_idx,
	input subcycle_t                         mx3_subcycle,
	                                        
	// Floating point addition pipeline                    
	input[`VECTOR_LANES - 1:0][23:0]         mx3_sum,
	input[`VECTOR_LANES - 1:0][7:0]          mx3_exponent,
	input[`VECTOR_LANES - 1:0]               mx3_result_sign,
	input[`VECTOR_LANES - 1:0]               mx3_logical_subtract,
	                                        
	// To mx4 stage                         
	output                                   mx4_instruction_valid,
	output decoded_instruction_t             mx4_instruction,
	output [`VECTOR_LANES - 1:0]             mx4_mask_value,
	output thread_idx_t                      mx4_thread_idx,
	output subcycle_t                        mx4_subcycle,
	
	// Floating point addition pipeline                    
	output logic[`VECTOR_LANES - 1:0][7:0]   mx4_exponent,
	output logic[`VECTOR_LANES - 1:0][23:0]  mx4_significand,
	output logic[`VECTOR_LANES - 1:0]        mx4_result_sign,
	output logic[`VECTOR_LANES - 1:0]        mx4_logical_subtract,
	output logic[`VECTOR_LANES - 1:0][4:0]   mx4_norm_shift);

	genvar lane_idx;
	generate
		for (lane_idx = 0; lane_idx < `VECTOR_LANES; lane_idx++)
		begin : lane_logic
			int leading_zeroes;
			logic[23:0] significand_from_mx3;
			logic[4:0] norm_shift_nxt;
			
			assign significand_from_mx3 = mx3_sum[lane_idx]; 	// XXX needs to mux in mult result
			
			// Leading zero detection: determine normalization shift amount 
			// (shared by addition and multiplication)
			always_comb
			begin
				// XXX norm_shift_nxt needs to be twos complement.
				norm_shift_nxt = 0;
				casez (significand_from_mx3)	
					24'b1???????????????????????: norm_shift_nxt = 0;
					24'b01??????????????????????: norm_shift_nxt = 1;
					24'b001?????????????????????: norm_shift_nxt = 2;
					24'b0001????????????????????: norm_shift_nxt = 3;
					24'b00001???????????????????: norm_shift_nxt = 4;
					24'b000001??????????????????: norm_shift_nxt = 5;
					24'b0000001?????????????????: norm_shift_nxt = 6;
					24'b00000001????????????????: norm_shift_nxt = 7;
					24'b000000001???????????????: norm_shift_nxt = 8;
					24'b0000000001??????????????: norm_shift_nxt = 9;
					24'b00000000001?????????????: norm_shift_nxt = 10;
					24'b000000000001????????????: norm_shift_nxt = 11;
					24'b0000000000001???????????: norm_shift_nxt = 12;
					24'b00000000000001??????????: norm_shift_nxt = 13;
					24'b000000000000001?????????: norm_shift_nxt = 14;
					24'b0000000000000001????????: norm_shift_nxt = 15;
					24'b00000000000000001???????: norm_shift_nxt = 16;
					24'b000000000000000001??????: norm_shift_nxt = 17;
					24'b0000000000000000001?????: norm_shift_nxt = 18;
					24'b00000000000000000001????: norm_shift_nxt = 19;
					24'b000000000000000000001???: norm_shift_nxt = 20;
					24'b0000000000000000000001??: norm_shift_nxt = 21;
					24'b00000000000000000000001?: norm_shift_nxt = 22;
					24'b000000000000000000000001: norm_shift_nxt = 23;
					24'b000000000000000000000000: norm_shift_nxt = 24;
				endcase
			end
			
			always @(posedge clk)
			begin
				mx4_significand[lane_idx] <= significand_from_mx3;
				mx4_norm_shift[lane_idx] <= norm_shift_nxt;
				mx4_exponent[lane_idx] <= mx3_exponent[lane_idx];
				mx4_result_sign[lane_idx] <= mx3_result_sign[lane_idx];
				mx4_logical_subtract[lane_idx] <= mx3_logical_subtract[lane_idx];
			end
		end
	endgenerate
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			mx4_instruction <= 0;
			mx4_instruction_valid <= 0;
			mx4_mask_value <= 0;
			mx4_thread_idx <= 0;
			mx4_subcycle <= 0;
		end
		else
		begin
			mx4_instruction <= mx3_instruction;
			mx4_instruction_valid <= mx3_instruction_valid;
			mx4_mask_value <= mx3_mask_value;
			mx4_thread_idx <= mx3_thread_idx;
			mx4_subcycle <= mx3_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
