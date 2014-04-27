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
	input subcycle_t                  of_subcycle,
	
	// From writeback stage
	input logic                       wb_rollback_en,
	input thread_idx_t                wb_rollback_thread_idx,
	
	// To writeback stage
	output                            sx_instruction_valid,
	output decoded_instruction_t      sx_instruction,
	output vector_t                   sx_result,
	output [`VECTOR_LANES - 1:0]      sx_mask_value,
	output thread_idx_t               sx_thread_idx,
	output logic                      sx_rollback_en,
	output thread_idx_t               sx_rollback_thread_idx,
	output scalar_t                   sx_rollback_pc,
	output subcycle_t                 sx_subcycle);

	vector_t vector_result;

	genvar lane;
	generate
		for (lane = 0; lane < `VECTOR_LANES; lane++)
		begin : lane_alu
			scalar_t lane_operand1;
			scalar_t lane_operand2;
			scalar_t lane_result;
			scalar_t difference;
			logic borrow;
			logic negative; 
			logic overflow;
			logic zero;
			logic signed_gtr;
			logic[4:0] leading_zeroes;
			logic[4:0] trailing_zeroes;
			
			assign lane_operand1 = of_operand1[lane];
			assign lane_operand2 = of_operand2[lane];
			assign { borrow, difference } = { 1'b0, lane_operand1 } - { 1'b0, lane_operand2 };
			assign negative = difference[31]; 
			assign overflow = lane_operand2[31] == negative && lane_operand1[31] != lane_operand2[31];
			assign zero = difference == 0;
			assign signed_gtr = overflow == negative;

			// Use a single shifter (with some muxes in front) to handle FTOI and integer 
			// arithmetic shifts.
			wire shift_in_sign = of_instruction.alu_op == OP_ASR ? lane_operand1[31] : 1'd0;
			wire[31:0] rshift = { {32{shift_in_sign}}, lane_operand1 } >> lane_operand2[4:0];

			always_comb
			begin
				case (of_instruction.alu_op)
					OP_ASR,
					OP_LSR: lane_result = lane_operand2[31:5] == 0 ? rshift : {32{shift_in_sign}};	   
					OP_LSL: lane_result = lane_operand2[31:5] == 0 ? lane_operand1 << lane_operand2[4:0] : 0;
					OP_COPY: lane_result = lane_operand2;
					OP_OR: lane_result = lane_operand1 | lane_operand2;
					OP_AND: lane_result = lane_operand1 & lane_operand2;
					OP_UMINUS: lane_result = -lane_operand2;
					OP_XOR: lane_result = lane_operand1 ^ lane_operand2;
					OP_IADD: lane_result = lane_operand1 + lane_operand2;	
					OP_ISUB: lane_result = difference;
					OP_EQUAL: lane_result = { {31{1'b0}}, zero };	  
					OP_NEQUAL: lane_result = { {31{1'b0}}, !zero }; 
					OP_SIGTR: lane_result = { {31{1'b0}}, signed_gtr && !zero };
					OP_SIGTE: lane_result = { {31{1'b0}}, signed_gtr || zero }; 
					OP_SILT: lane_result = { {31{1'b0}}, !signed_gtr && !zero}; 
					OP_SILTE: lane_result = { {31{1'b0}}, !signed_gtr || zero };
					OP_UIGTR: lane_result = { {31{1'b0}}, !borrow && !zero };
					OP_UIGTE: lane_result = { {31{1'b0}}, !borrow || zero };
					OP_UILT: lane_result = { {31{1'b0}}, borrow && !zero };
					OP_UILTE: lane_result = { {31{1'b0}}, borrow || zero };
					OP_SEXT8: lane_result = { {24{lane_operand2[7]}}, lane_operand2[7:0] };
					OP_SEXT16: lane_result = { {16{lane_operand2[15]}}, lane_operand2[15:0] };
					OP_SHUFFLE,
					OP_GETLANE: lane_result = of_operand1[`VECTOR_LANES - 1 - lane_operand2];
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
			sx_instruction <= 0;
			
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			sx_instruction_valid <= 1'h0;
			sx_mask_value <= {(1+(`VECTOR_LANES-1)){1'b0}};
			sx_result <= 1'h0;
			sx_rollback_en <= 1'h0;
			sx_rollback_pc <= 1'h0;
			sx_rollback_thread_idx <= 1'h0;
			sx_subcycle <= 1'h0;
			sx_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			sx_instruction <= of_instruction;
			sx_result <= vector_result;
			sx_mask_value <= of_mask_value;
			sx_thread_idx <= of_thread_idx;
			sx_subcycle <= of_subcycle;

			// XXX cleanup
			if (of_instruction_valid 
				&& (!wb_rollback_en || wb_rollback_thread_idx != of_thread_idx) 
				&& of_instruction.pipeline_sel == PIPE_SCYCLE_ARITH)
			begin
				sx_instruction_valid <= 1;

				//
				// Branch handling
				//
				sx_rollback_thread_idx <= of_thread_idx;
				if (of_instruction.branch_type == BRANCH_CALL_REGISTER)
					sx_rollback_pc <= of_operand1[0];
				else 
					sx_rollback_pc <= of_instruction.pc + of_instruction.immediate_value;

				if (of_instruction.is_branch)
				begin
					// XXX need to make sure operand 1 is passed through to result correctly.
					case (of_instruction.branch_type)
						BRANCH_ALL:            sx_rollback_en <= of_operand1[0][15:0] == 16'hffff;
						BRANCH_ZERO:           sx_rollback_en <= of_operand1[0] == 0;
						BRANCH_NOT_ZERO:       sx_rollback_en <= of_operand1[0] != 0;
						BRANCH_ALWAYS:         sx_rollback_en <= 1'b1;
						BRANCH_CALL_OFFSET:    sx_rollback_en <= 1'b1;
						BRANCH_NOT_ALL:        sx_rollback_en <= of_operand1[0][15:0] == 16'h0000;
						BRANCH_CALL_REGISTER:  sx_rollback_en <= 1'b1;
					endcase
				end
				else
					sx_rollback_en <= 0;
			end
			else
			begin
				sx_instruction_valid <= 0;
				sx_rollback_en <= 0;
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
