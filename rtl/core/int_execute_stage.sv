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
// Instruction Pipeline Integer Execute Stage
// - Perform simple operations that only require a single stage like logical operations,
// integer add, etc. 
// - Branch handling
// 

module int_execute_stage(
	input                             clk,
	input                             reset,
	
	// From operand fetch stage
	input vector_t                    of_operand1,
	input vector_t                    of_operand2,
	input vector_lane_mask_t          of_mask_value,
	input vector_t                    of_store_value,
	input                             of_instruction_valid,
	input decoded_instruction_t       of_instruction,
	input thread_idx_t                of_thread_idx,
	input subcycle_t                  of_subcycle,
	
	// From writeback stage
	input logic                       wb_rollback_en,
	input thread_idx_t                wb_rollback_thread_idx,
	
	// To/From control register
	input scalar_t                    cr_eret_address[`THREADS_PER_CORE],
	output logic                      ix_is_eret,
	
	// To writeback stage
	output                            ix_instruction_valid,
	output decoded_instruction_t      ix_instruction,
	output vector_t                   ix_result,
	output vector_lane_mask_t         ix_mask_value,
	output thread_idx_t               ix_thread_idx,
	output logic                      ix_rollback_en,
	output scalar_t                   ix_rollback_pc,
	output subcycle_t                 ix_subcycle);

	vector_t vector_result;

	genvar lane;
	generate
		for (lane = 0; lane < `VECTOR_LANES; lane++)
		begin : lane_alu_gen
			scalar_t lane_operand1;
			scalar_t lane_operand2;
			scalar_t lane_result;
			scalar_t difference;
			logic borrow;
			logic negative; 
			logic overflow;
			logic zero;
			logic signed_gtr;
			logic[5:0] lz;
			logic[5:0] tz;
			scalar_t reciprocal;
			ieee754_binary32_t fp_operand;
			logic[5:0] reciprocal_estimate;
			logic shift_in_sign;
			scalar_t rshift;
			
			assign lane_operand1 = of_operand1[lane];
			assign lane_operand2 = of_operand2[lane];
			assign { borrow, difference } = { 1'b0, lane_operand1 } - { 1'b0, lane_operand2 };
			assign negative = difference[31]; 
			assign overflow = lane_operand2[31] == negative && lane_operand1[31] != lane_operand2[31];
			assign zero = difference == 0;
			assign signed_gtr = overflow == negative;

			// Count leading zeroes
			always_comb
			begin
				casez (lane_operand2)
					32'b1???????????????????????????????: lz = 0;
					32'b01??????????????????????????????: lz = 1;
					32'b001?????????????????????????????: lz = 2;
					32'b0001????????????????????????????: lz = 3;
					32'b00001???????????????????????????: lz = 4;
					32'b000001??????????????????????????: lz = 5;
					32'b0000001?????????????????????????: lz = 6;
					32'b00000001????????????????????????: lz = 7;
					32'b000000001???????????????????????: lz = 8;
					32'b0000000001??????????????????????: lz = 9;
					32'b00000000001?????????????????????: lz = 10;
					32'b000000000001????????????????????: lz = 11;
					32'b0000000000001???????????????????: lz = 12;
					32'b00000000000001??????????????????: lz = 13;
					32'b000000000000001?????????????????: lz = 14;
					32'b0000000000000001????????????????: lz = 15;
					32'b00000000000000001???????????????: lz = 16;
					32'b000000000000000001??????????????: lz = 17;
					32'b0000000000000000001?????????????: lz = 18;
					32'b00000000000000000001????????????: lz = 19;
					32'b000000000000000000001???????????: lz = 20;
					32'b0000000000000000000001??????????: lz = 21;
					32'b00000000000000000000001?????????: lz = 22;
					32'b000000000000000000000001????????: lz = 23;
					32'b0000000000000000000000001???????: lz = 24;
					32'b00000000000000000000000001??????: lz = 25;
					32'b000000000000000000000000001?????: lz = 26;
					32'b0000000000000000000000000001????: lz = 27;
					32'b00000000000000000000000000001???: lz = 28;
					32'b000000000000000000000000000001??: lz = 29;
					32'b0000000000000000000000000000001?: lz = 30;
					32'b00000000000000000000000000000001: lz = 31;
					32'b00000000000000000000000000000000: lz = 32;
					default: lz = 0;
				endcase
			end

			// Count trailing zeroes
			always_comb
			begin
				casez (lane_operand2)
					32'b00000000000000000000000000000000: tz = 32;
					32'b10000000000000000000000000000000: tz = 31;
					32'b?1000000000000000000000000000000: tz = 30;
					32'b??100000000000000000000000000000: tz = 29;
					32'b???10000000000000000000000000000: tz = 28;
					32'b????1000000000000000000000000000: tz = 27;
					32'b?????100000000000000000000000000: tz = 26;
					32'b??????10000000000000000000000000: tz = 25;
					32'b???????1000000000000000000000000: tz = 24;
					32'b????????100000000000000000000000: tz = 23;
					32'b?????????10000000000000000000000: tz = 22;
					32'b??????????1000000000000000000000: tz = 21;
					32'b???????????100000000000000000000: tz = 20;
					32'b????????????10000000000000000000: tz = 19;
					32'b?????????????1000000000000000000: tz = 18;
					32'b??????????????100000000000000000: tz = 17;
					32'b???????????????10000000000000000: tz = 16;
					32'b????????????????1000000000000000: tz = 15;
					32'b?????????????????100000000000000: tz = 14;
					32'b??????????????????10000000000000: tz = 13;
					32'b???????????????????1000000000000: tz = 12;
					32'b????????????????????100000000000: tz = 11;
					32'b?????????????????????10000000000: tz = 10;
					32'b??????????????????????1000000000: tz = 9;
					32'b???????????????????????100000000: tz = 8;
					32'b????????????????????????10000000: tz = 7;
					32'b?????????????????????????1000000: tz = 6;
					32'b??????????????????????????100000: tz = 5;
					32'b???????????????????????????10000: tz = 4;
					32'b????????????????????????????1000: tz = 3;
					32'b?????????????????????????????100: tz = 2;
					32'b??????????????????????????????10: tz = 1;
					32'b???????????????????????????????1: tz = 0;
					default: tz = 0;
				endcase
			end

			// Right shift
			assign shift_in_sign = of_instruction.alu_op == OP_ASHR ? lane_operand1[31] : 1'd0;
			assign rshift = { {32{shift_in_sign}}, lane_operand1 } >> lane_operand2[4:0];

			// Reciprocal estimate
			assign fp_operand = lane_operand2;
			reciprocal_rom rom(
				.significand(fp_operand.significand[22:17]),
				.reciprocal_estimate);

			always_comb
			begin
				if (fp_operand.exponent == 0)
				begin
					// Any subnormal will effectively overflow the exponent field, so convert
					// to infinity (this also captures division by zero).
					reciprocal = { fp_operand.sign, 8'hff, 23'd0 }; // inf
				end
				else if (fp_operand.exponent == 8'hff)
				begin
					if (fp_operand.significand)
						reciprocal = { 1'b0, 8'hff, 23'h7fffff }; // Division by NaN = NaN
					else
						reciprocal = { fp_operand.sign, 8'h00, 23'h000000 }; // Division by +/-inf = +/-0.0
				end
				else 
				begin
					reciprocal = { fp_operand.sign, 8'd253 - fp_operand.exponent + (fp_operand.significand[22:17] == 0), 
						reciprocal_estimate, {17{1'b0}} };
				end
			end

			always_comb
			begin
				case (of_instruction.alu_op)
					OP_ASHR,
					OP_SHR: lane_result = rshift;	   
					OP_SHL: lane_result = lane_operand1 << lane_operand2[4:0];
					OP_MOVE: lane_result = lane_operand2;
					OP_OR: lane_result = lane_operand1 | lane_operand2;
					OP_CLZ: lane_result = lz;
					OP_CTZ: lane_result = tz;
					OP_AND: lane_result = lane_operand1 & lane_operand2;
					OP_XOR: lane_result = lane_operand1 ^ lane_operand2;
					OP_ADD_I: lane_result = lane_operand1 + lane_operand2;	
					OP_SUB_I: lane_result = difference;
					OP_CMPEQ_I: lane_result = { {31{1'b0}}, zero };	  
					OP_CMPNE_I: lane_result = { {31{1'b0}}, !zero }; 
					OP_CMPGT_I: lane_result = { {31{1'b0}}, signed_gtr && !zero };
					OP_CMPGE_I: lane_result = { {31{1'b0}}, signed_gtr || zero }; 
					OP_CMPLT_I: lane_result = { {31{1'b0}}, !signed_gtr && !zero}; 
					OP_CMPLE_I: lane_result = { {31{1'b0}}, !signed_gtr || zero };
					OP_CMPGT_U: lane_result = { {31{1'b0}}, !borrow && !zero };
					OP_CMPGE_U: lane_result = { {31{1'b0}}, !borrow || zero };
					OP_CMPLT_U: lane_result = { {31{1'b0}}, borrow && !zero };
					OP_CMPLE_U: lane_result = { {31{1'b0}}, borrow || zero };
					OP_SEXT8: lane_result = { {24{lane_operand2[7]}}, lane_operand2[7:0] };
					OP_SEXT16: lane_result = { {16{lane_operand2[15]}}, lane_operand2[15:0] };
					OP_SHUFFLE,
					OP_GETLANE: lane_result = of_operand1[~lane_operand2];
					OP_RECIPROCAL: lane_result = reciprocal;
					default: lane_result = 0;
				endcase
			end
			
			assign vector_result[lane] = lane_result;
		end
	endgenerate
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			ix_instruction <= 0;
			
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			ix_instruction_valid <= 1'h0;
			ix_is_eret <= 1'h0;
			ix_mask_value <= 1'h0;
			ix_result <= 1'h0;
			ix_rollback_en <= 1'h0;
			ix_rollback_pc <= 1'h0;
			ix_subcycle <= 1'h0;
			ix_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			ix_instruction <= of_instruction;
			ix_result <= vector_result;
			ix_mask_value <= of_mask_value;
			ix_thread_idx <= of_thread_idx;
			ix_subcycle <= of_subcycle;

			if (of_instruction_valid 
				&& (!wb_rollback_en || wb_rollback_thread_idx != of_thread_idx) 
				&& of_instruction.pipeline_sel == PIPE_SCYCLE_ARITH)
			begin
				ix_instruction_valid <= 1;

				//
				// Branch handling
				//
				unique case (of_instruction.branch_type)
					BRANCH_CALL_REGISTER: ix_rollback_pc <= of_operand1[0];
					BRANCH_ERET: ix_rollback_pc <= cr_eret_address[of_thread_idx];
					default: 
						ix_rollback_pc <= of_instruction.pc + 4 + of_instruction.immediate_value;
				endcase 

				ix_is_eret <= of_instruction.is_branch && of_instruction.branch_type == BRANCH_ERET;

				if (of_instruction.is_branch && !of_instruction.illegal)
				begin
					unique case (of_instruction.branch_type)
						BRANCH_ALL:            ix_rollback_en <= of_operand1[0][15:0] == 16'hffff;
						BRANCH_ZERO:           ix_rollback_en <= of_operand1[0] == 0;
						BRANCH_NOT_ZERO:       ix_rollback_en <= of_operand1[0] != 0;
						BRANCH_NOT_ALL:        ix_rollback_en <= of_operand1[0][15:0] != 16'hffff;
						BRANCH_ALWAYS,         
						BRANCH_CALL_OFFSET,    
						BRANCH_CALL_REGISTER,  
						BRANCH_ERET:        ix_rollback_en <= 1'b1;
					endcase
				end
				else
					ix_rollback_en <= 0;
			end
			else
			begin
				ix_instruction_valid <= 0;
				ix_rollback_en <= 0;
				ix_is_eret <= 0;
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
