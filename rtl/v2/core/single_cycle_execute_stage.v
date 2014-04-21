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
			
			assign lane_operand1 = of_operand1[lane];
			assign lane_operand2 = of_operand2[lane];
		
			always_comb
			begin
				case (of_instruction.alu_op)
					OP_COPY: lane_result = lane_operand2;
					OP_OR: lane_result = lane_operand1 | lane_operand2;
					OP_AND: lane_result = lane_operand1 & lane_operand2;
					OP_UMINUS: lane_result = -lane_operand2;
					OP_XOR: lane_result = lane_operand1 ^ lane_operand2;
					OP_IADD: lane_result = lane_operand1 + lane_operand2;		
					OP_ISUB: lane_result = lane_operand1 - lane_operand2;
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
