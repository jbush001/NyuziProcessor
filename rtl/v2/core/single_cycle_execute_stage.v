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
// - Perform simple operations that only require a single stage like logical operations,
// integer add, etc. 
// - Detect branches and perform rollbacks
// 

module single_cycle_execute_stage(
	input                             clk,
	input                             reset,
	
	// From operand fetch stage
	input vector_t                    of_operand1,
	input vector_t                    of_operand2,
	input [`VECTOR_LANES - 1:0]       of_mask_value,
	input vector_t                    of_store_value,
	input                             of_instruction_valid,
	input decoded_instruction_t       of_instruction,
	input thread_idx_t                of_thread_idx,
	
	// From writeback stage
	input logic                      wb_rollback_en,
	input thread_idx_t               wb_rollback_thread_idx,
	
	// To writeback stage
	output                            sc_instruction_valid,
	output decoded_instruction_t      sc_instruction,
	output vector_t                   sc_result,
	output [`VECTOR_LANES - 1:0]      sc_mask_value,
	output thread_idx_t               sc_thread_idx,
	output logic                      sc_rollback_en,
	output thread_idx_t               sc_rollback_thread_idx,
	output scalar_t                   sc_rollback_pc);

	vector_t vector_result;

	genvar lane;
	generate
		for (lane = 0; lane < `VECTOR_LANES; lane++)
		begin : lane_alu
			scalar_t lane_operand1;
			scalar_t lane_operand2;
			scalar_t lane_result;
			logic carry;
			logic _ignore;
			scalar_t sum_difference;
			logic do_subtract;
			logic negative; 
			logic overflow;
			logic zero;
			logic signed_gtr;
			logic[4:0] leading_zeroes;
			logic[4:0] trailing_zeroes;
			
			assign lane_operand1 = of_operand1[lane];
			assign lane_operand2 = of_operand2[lane];
			assign do_subtract = of_instruction.alu_op != OP_IADD;
			assign { carry, sum_difference, _ignore } = { 1'b0, lane_operand1, do_subtract } 
				+ { do_subtract, {32{do_subtract}} ^ lane_operand2, do_subtract };
			assign negative = sum_difference[31]; 
			assign overflow =	lane_operand2[31] == negative && lane_operand1[31] != lane_operand2[31];
			assign zero = sum_difference == 0;
			assign signed_gtr = overflow == negative;

			// Count trailing zeroes using binary search
			wire tz4 = (lane_operand2[15:0] == 16'b0);
			wire[15:0] tz_val16 = tz4 ? lane_operand2[31:16] : lane_operand2[15:0];
			wire tz3 = (tz_val16[7:0] == 8'b0);
			wire[7:0] tz_val8 = tz3 ? tz_val16[15:8] : tz_val16[7:0];
			wire tz2 = (tz_val8[3:0] == 4'b0);
			wire[3:0] tz_val4 = tz2 ? tz_val8[7:4] : tz_val8[3:0];
			wire tz1 = (tz_val4[1:0] == 2'b0);
			wire tz0 = tz1 ? ~tz_val4[2] : ~tz_val4[0];
			assign trailing_zeroes = { tz4, tz3, tz2, tz1, tz0 };

			// Count leading zeroes, as above except reversed
			wire lz4 = (lane_operand2[31:16] == 16'b0);
			wire[15:0] lz_val16 = lz4 ? lane_operand2[15:0] : lane_operand2[31:16];
			wire lz3 = (lz_val16[15:8] == 8'b0);
			wire[7:0] lz_val8 = lz3 ? lz_val16[7:0] : lz_val16[15:8];
			wire lz2 = (lz_val8[7:4] == 4'b0);
			wire[3:0] lz_val4 = lz2 ? lz_val8[3:0] : lz_val8[7:4];
			wire lz1 = (lz_val4[3:2] == 2'b0);
			wire lz0 = lz1 ? ~lz_val4[1] : ~lz_val4[3];
			assign leading_zeroes = { lz4, lz3, lz2, lz1, lz0 };

			// Use a single shifter (with some muxes in front) to handle FTOI and integer 
			// arithmetic shifts.
			wire fp_sign = lane_operand2[31];
			wire[7:0] fp_exponent = lane_operand2[30:23];
			wire[23:0] fp_significand = { 1'b1, lane_operand2[22:0] };
			wire[4:0] shift_amount = of_instruction.alu_op == OP_FTOI 
				? 23 - (fp_exponent - 127)
				: lane_operand2[4:0];
			wire[31:0] shift_in = of_instruction.alu_op == OP_FTOI ? fp_significand : lane_operand1;
			wire shift_in_sign = of_instruction.alu_op == OP_ASR ? lane_operand1[31] : 1'd0;
			wire[31:0] rshift = { {32{shift_in_sign}}, shift_in } >> shift_amount;

			// Reciprocal estimate
			wire[31:0] reciprocal;
			fp_reciprocal_estimate fp_reciprocal_estimate(
				.value_i(lane_operand2),
				.value_o(reciprocal));
		
			always_comb
			begin
				case (of_instruction.alu_op)
					OP_ASR,
					OP_LSR: lane_result = lane_operand2[31:5] == 0 ? rshift : {32{shift_in_sign}};	   
					OP_LSL: lane_result = lane_operand2[31:5] == 0 ? lane_operand1 << lane_operand2[4:0] : 0;
					OP_CLZ: lane_result = lane_operand2 == 0 ? 32 : leading_zeroes;	  
					OP_CTZ: lane_result = lane_operand2 == 0 ? 32 : trailing_zeroes;
					OP_COPY: lane_result = lane_operand2;
					OP_OR: lane_result = lane_operand1 | lane_operand2;
					OP_AND: lane_result = lane_operand1 & lane_operand2;
					OP_UMINUS: lane_result = -lane_operand2;
					OP_XOR: lane_result = lane_operand1 ^ lane_operand2;
					OP_IADD,		
					OP_ISUB: lane_result = sum_difference;
					OP_EQUAL: lane_result = { {31{1'b0}}, zero };	  
					OP_NEQUAL: lane_result = { {31{1'b0}}, ~zero }; 
					OP_SIGTR: lane_result = { {31{1'b0}}, signed_gtr & ~zero };
					OP_SIGTE: lane_result = { {31{1'b0}}, signed_gtr | zero }; 
					OP_SILT: lane_result = { {31{1'b0}}, ~signed_gtr & ~zero}; 
					OP_SILTE: lane_result = { {31{1'b0}}, ~signed_gtr | zero };
					OP_UIGTR: lane_result = { {31{1'b0}}, ~carry & ~zero };
					OP_UIGTE: lane_result = { {31{1'b0}}, ~carry | zero };
					OP_UILT: lane_result = { {31{1'b0}}, carry & ~zero };
					OP_UILTE: lane_result = { {31{1'b0}}, carry | zero };
					OP_RECIP: lane_result = reciprocal;
					OP_SEXT8: lane_result = { {24{lane_operand2[7]}}, lane_operand2[7:0] };
					OP_SEXT16: lane_result = { {16{lane_operand2[15]}}, lane_operand2[15:0] };
					OP_FTOI:
					begin
						if (!fp_exponent[7])	// Exponent negative (value smaller than zero)
							lane_result = 0;
						else if (fp_sign)
							lane_result = ~rshift + 1;
						else
							lane_result = rshift;
					end
					default: lane_result = 0;
				endcase
			end
			
			assign vector_result[lane] = lane_result;
		end
	endgenerate

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			sc_instruction <= 0;
			
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			sc_instruction_valid <= 1'h0;
			sc_mask_value <= {(1+(`VECTOR_LANES-1)){1'b0}};
			sc_result <= 1'h0;
			sc_rollback_en <= 1'h0;
			sc_rollback_pc <= 1'h0;
			sc_rollback_thread_idx <= 1'h0;
			sc_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			sc_instruction <= of_instruction;
			sc_result <= vector_result;
			sc_mask_value <= of_mask_value;
			sc_thread_idx <= of_thread_idx;

			// XXX cleanup
			if (of_instruction_valid 
				&& (!wb_rollback_en || wb_rollback_thread_idx != of_thread_idx) 
				&& of_instruction.pipeline_sel == PIPE_SCYCLE_ARITH)
			begin
				sc_instruction_valid <= 1;

				//
				// Branch handling
				//
				sc_rollback_thread_idx <= of_thread_idx;
				if (of_instruction.branch_type == BRANCH_CALL_REGISTER)
					sc_rollback_pc <= of_operand1[0];
				else 
					sc_rollback_pc <= of_instruction.pc + of_instruction.immediate_value;

				if (of_instruction.is_branch)
				begin
					// XXX need to make sure operand 1 is passed through to result correctly.
					case (of_instruction.branch_type)
						BRANCH_ALL:            sc_rollback_en <= of_operand1[0][15:0] == 16'hffff;
						BRANCH_ZERO:           sc_rollback_en <= of_operand1[0] == 0;
						BRANCH_NOT_ZERO:       sc_rollback_en <= of_operand1[0] != 0;
						BRANCH_ALWAYS:         sc_rollback_en <= 1'b1;
						BRANCH_CALL_OFFSET:    sc_rollback_en <= 1'b1;
						BRANCH_NOT_ALL:        sc_rollback_en <= of_operand1[0][15:0] == 16'h0000;
						BRANCH_CALL_REGISTER:  sc_rollback_en <= 1'b1;
					endcase
				end
				else
					sc_rollback_en <= 0;
			end
			else
			begin
				sc_instruction_valid <= 0;
				sc_rollback_en <= 0;
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
