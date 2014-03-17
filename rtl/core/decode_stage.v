// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

`include "defines.v"

//
// Instruction pipeline decode stage
// - Maps register addresses to register file ports and issues request to latter.
// - Decodes writeback destination, which will be propagated down the pipeline
//   for bypassing.
//
// Register port to operand mapping
//                                               store 
//       format           op1     op2    mask    value
// +-------------------+-------+-------+-------+-------+
// | A - scalar/scalar |   s1  |   s2  |       |       |
// | A - vector/scalar |   v1  |   s2  |  s1   |       |
// | A - vector/vector |   v1  |   v2  |  s2   |       |
// | B - scalar        |   s1  |  imm  |  n/a  |       |
// | B - vector        |   v1  |  imm  |  s2   |       |
// | C - scalar        |   s1  |  imm  |  n/a  |  s2   |
// | C - block         |   s1  |  imm  |  s2   |  v2   |
// | C - strided       |   s1  |  imm  |  s2   |  v2   |
// | C - scatter/gather|   v1  |  imm  |  s2   |  v2   |
// | D                 |   s1  |  imm  |       |       |
// | E                 |   s1  |       |       |       |
// +-------------------+-------+-------+-------+-------+
//

module decode_stage(
	input                                   clk,
	input                                   reset,

	// From rollback controller
	input                                   rb_squash_ds,

	// From strand select stage
	input[31:0]                             ss_instruction,
	input[`STRAND_INDEX_WIDTH - 1:0]        ss_strand,
	input                                   ss_branch_predicted,
	input [31:0]                            ss_pc,
	input [31:0]                            ss_strided_offset,
	input                                   ss_long_latency,
	input [3:0]                             ss_reg_lane_select,

	// To register file
	output logic[`REG_IDX_WIDTH - 1:0]       ds_scalar_sel1,
	output logic[`REG_IDX_WIDTH - 1:0]       ds_scalar_sel2,
	output logic[`REG_IDX_WIDTH - 1:0]       ds_vector_sel1,
	output logic[`REG_IDX_WIDTH - 1:0]       ds_vector_sel2,

	// To execute stage
	output logic[31:0]                       ds_instruction,
	output logic[`STRAND_INDEX_WIDTH - 1:0]  ds_strand,
	output logic[31:0]                       ds_pc,
	output logic[31:0]                       ds_immediate_value,
	output mask_src_t                        ds_mask_src,
	output logic                             ds_op1_is_vector,
	output op2_src_t                         ds_op2_src,
	output logic                             ds_store_value_is_vector,
	output logic [`REG_IDX_WIDTH - 1:0]      ds_writeback_reg,
	output logic                             ds_enable_scalar_writeback,
	output logic                             ds_enable_vector_writeback,
	output logic[5:0]                        ds_alu_op,
	output logic[3:0]                        ds_reg_lane_select,
	output logic[31:0]                       ds_strided_offset,
	output logic                             ds_branch_predicted,
	output logic                             ds_long_latency,
	output logic[`REG_IDX_WIDTH - 1:0]       ds_vector_sel1_l,
	output logic[`REG_IDX_WIDTH - 1:0]       ds_vector_sel2_l,
	output logic[`REG_IDX_WIDTH - 1:0]       ds_scalar_sel1_l,
	output logic[`REG_IDX_WIDTH - 1:0]       ds_scalar_sel2_l,
	
	// Performance counters
	output                                  pc_event_vector_ins_issue,
	output                                  pc_event_mem_ins_issue);
	
	// Instruction Fields
	wire[4:0] src1_reg = ss_instruction[4:0];
	wire[4:0] src2_reg = ss_instruction[19:15];
	wire[4:0] mask_reg = ss_instruction[14:10];
	wire[4:0] dest_reg = ss_instruction[9:5];
	wire[2:0] a_fmt = ss_instruction[28:26];
	wire[5:0] a_opcode = ss_instruction[25:20];
	wire[2:0] b_fmt = ss_instruction[30:28];
	wire[4:0] b_opcode = ss_instruction[27:23];
	wire[31:0] b_immediate = { {24{ss_instruction[22]}}, ss_instruction[22:15] };
	wire[31:0] b_wide_immediate = { {19{ss_instruction[22]}}, ss_instruction[22:10] };
	wire[3:0] c_op = ss_instruction[28:25];
	wire[31:0] c_offset = { {22{ss_instruction[24]}}, ss_instruction[24:15] };
	wire[31:0] c_wide_offset = { {17{ss_instruction[24]}}, ss_instruction[24:10] };

	// Decode logic
	wire is_fmt_a = ss_instruction[31:29] == 3'b110;	
	wire is_fmt_b = ss_instruction[31] == 1'b0;	
	wire is_fmt_c = ss_instruction[31:30] == 2'b10;	
	wire is_vector_memory_transfer = c_op[3] == 1'b1 || c_op == `MEM_BLOCK;
	wire is_load = ss_instruction[29];	// Assumes is op c
	wire is_call = ss_instruction[31:25] == { 4'b1111, `BRANCH_CALL_OFFSET } 
		|| ss_instruction[31:25] == { 4'b1111, `BRANCH_CALL_REGISTER};

	wire writeback_is_vector;
	wire[5:0] alu_op_nxt;
	wire[31:0] immediate_nxt;
	wire op1_is_vector_nxt;
	op2_src_t op2_src_nxt;
	mask_src_t mask_src_nxt;

	// If there is no mask, use the mask field as part of the immediate.
	// For memory operations, the immediate is a multiple of the access size.
	always_comb
	begin
		priority casez (ss_instruction[31:25])
			// Format B
			7'b0_010_???,	// VVM
			7'b0_011_???, 	// VVM(invert)
			7'b0_101_???,	// VSM
			7'b0_110_???: 	// VSM(invert)
				immediate_nxt = b_immediate; // Masked vector
			
			7'b0_000_???, 
			7'b0_001_???, 
			7'b0_100_???, 
			7'b0_111_???: 
				immediate_nxt = b_wide_immediate; // No mask

			// Format C
			7'b10?_1000,	// block masked
			7'b10?_1001,	// block invert mask
			7'b10?_1110,	// scatter/gather masked
			7'b10?_1111:	// scatter/gather invert mask
				immediate_nxt = c_offset;
			
			7'b10?_????: 	// All other type C instructions
				immediate_nxt = c_wide_offset; // No mask, use longer imm field

			// Don't care or format D
			// (Note that the immediate field is unused for strided accesses:
			// it is sampled earlier in the pipeline).
			default: immediate_nxt = c_offset;	
		endcase
	end

	// Note that the register port selects are not registered, because the 
	// register file has one cycle of latency.  The registered outputs and 
	// the register fetch results will arrive at the same time to the
	// execute stage.

	always_comb
	begin
		if (is_fmt_a && (a_fmt == `FMTA_V_S 
			|| a_fmt == `FMTA_V_S_M
			|| a_fmt == `FMTA_V_S_IM))
		begin
			// A bit of a special case: since we are already using s2
			// to read the scalar operand, need to use s1 for the mask.
			ds_scalar_sel1 = { ss_strand, mask_reg };
		end
		else
			ds_scalar_sel1 = { ss_strand, src1_reg };
	end

	always_comb
	begin
		if (is_fmt_c && !is_load && !is_vector_memory_transfer)
			ds_scalar_sel2 = { ss_strand, dest_reg };
		else if (is_fmt_a && (a_fmt == `FMTA_S 
			|| a_fmt == `FMTA_V_S
			|| a_fmt == `FMTA_V_S_M 
			|| a_fmt == `FMTA_V_S_IM))
		begin
			ds_scalar_sel2 = { ss_strand, src2_reg };	// src2
		end
		else
			ds_scalar_sel2 = { ss_strand, mask_reg };	// mask
	end

	assign ds_vector_sel1 = { ss_strand, src1_reg };
	
	always_comb
	begin
		if (is_fmt_a && (a_fmt == `FMTA_V_V 
			|| a_fmt == `FMTA_V_V_M
			|| a_fmt == `FMTA_V_V_IM))
			ds_vector_sel2 = { ss_strand, src2_reg };	// src2
		else
			ds_vector_sel2 = { ss_strand, dest_reg }; // store value
	end

	always_comb
	begin
		if (is_fmt_a)
			op1_is_vector_nxt = a_fmt != `FMTA_S;
		else if (is_fmt_b)
		begin
			op1_is_vector_nxt = b_fmt == `FMTB_V_V
				|| b_fmt == `FMTB_V_V_M
				|| b_fmt == `FMTB_V_V_IM;
		end
		else if (is_fmt_c)
			op1_is_vector_nxt = c_op == `MEM_SCGATH 
				|| c_op == `MEM_SCGATH_M
				|| c_op == `MEM_SCGATH_IM;
		else
			op1_is_vector_nxt = 1'b0;
	end

	always_comb
	begin
		if (is_fmt_a)
		begin
			if (a_fmt == `FMTA_V_V
				|| a_fmt == `FMTA_V_V_M
				|| a_fmt == `FMTA_V_V_IM)
				op2_src_nxt = OP2_SRC_VECTOR2;	// Vector operand
			else
				op2_src_nxt = OP2_SRC_SCALAR2;	// Scalar operand
		end
		else	// Format B or C or don't care
			op2_src_nxt = OP2_SRC_IMMEDIATE;	// Immediate operand
	end
	
	always_comb
	begin
		priority casez (ss_instruction[31:25])
			// Format A (arithmetic)
			7'b110_010?: mask_src_nxt = MASK_SRC_SCALAR1;
			7'b110_011?: mask_src_nxt = MASK_SRC_SCALAR1_INV;
			7'b110_101?: mask_src_nxt = MASK_SRC_SCALAR2;
			7'b110_110?: mask_src_nxt = MASK_SRC_SCALAR2_INV;

			// Format B (immediate arithmetic)
			7'b0_010_???,
			7'b0_101_???: mask_src_nxt = MASK_SRC_SCALAR2;

			7'b0_011_???,
			7'b0_110_???: mask_src_nxt = MASK_SRC_SCALAR2_INV;

			// Format C (memory access)			
			7'b10?_1000,
			7'b10?_1011,
			7'b10?_1110: mask_src_nxt = MASK_SRC_SCALAR2;
			
			7'b10?_1001,
			7'b10?_1100,
			7'b10?_1111: mask_src_nxt = MASK_SRC_SCALAR2_INV;

			// All others
			default: mask_src_nxt = MASK_SRC_ALL_ONES;
		endcase
	end
	
	wire store_value_is_vector_nxt = !(is_fmt_c && !is_vector_memory_transfer);

	always_comb
	begin
		if (is_fmt_a)
			alu_op_nxt = a_opcode;
		else if (is_fmt_b)
			alu_op_nxt = b_opcode;
		else 
			alu_op_nxt = `OP_IADD;	// Addition (for offsets)
	end

	wire has_writeback = (is_fmt_a 
		|| is_fmt_b 
		|| (is_fmt_c && is_load) 		// Load
		|| (is_fmt_c && c_op == `MEM_SYNC)	// Synchronized load/store
		|| is_call)
		&& ss_instruction != `NOP;	// XXX check for nop for debugging

	wire[`REG_IDX_WIDTH - 1:0] writeback_reg_nxt = is_call ? { ss_strand, `REG_LINK }
		: { ss_strand, dest_reg };

	always_comb
	begin
		if (is_fmt_a)
		begin
			// These types always_combhave a scalar destination, even if the operands
			// are vector registers.
			unique case (a_opcode)
				`OP_EQUAL,	
				`OP_NEQUAL,	
				`OP_SIGTR,	
				`OP_SIGTE,	
				`OP_SILT,		
				`OP_SILTE,	
				`OP_UIGTR,	
				`OP_UIGTE,	
				`OP_UILT,		
				`OP_UILTE,
				`OP_FGTR,
				`OP_FLT,
				`OP_FGTE,	
				`OP_FLTE,
				`OP_GETLANE: writeback_is_vector = 0;
				default: writeback_is_vector = a_fmt != `FMTA_S;
			endcase
		end
		else if (is_fmt_b)
		begin
			// These types always_combhave a scalar destination, even if the operands
			// are vector registers.
			unique case (b_opcode)
				`OP_EQUAL,	
				`OP_NEQUAL,	
				`OP_SIGTR,	
				`OP_SIGTE,	
				`OP_SILT,		
				`OP_SILTE,	
				`OP_UIGTR,	
				`OP_UIGTE,	
				`OP_UILT,		
				`OP_UILTE,
				`OP_GETLANE: writeback_is_vector = 0;
				default: writeback_is_vector = b_fmt != `FMTB_S_S;
			endcase
		end
		else if (is_call)
			writeback_is_vector = 0;
		else // is_fmt_c or don't care...
			writeback_is_vector = is_vector_memory_transfer;
	end

	assign pc_event_vector_ins_issue = ds_enable_vector_writeback;
	assign pc_event_mem_ins_issue = is_fmt_c;	// Note: also includes control registers

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			ds_mask_src <= MASK_SRC_SCALAR1;
			ds_op2_src <= OP2_SRC_SCALAR2;
			
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			ds_alu_op <= 6'h0;
			ds_branch_predicted <= 1'h0;
			ds_enable_scalar_writeback <= 1'h0;
			ds_enable_vector_writeback <= 1'h0;
			ds_immediate_value <= 32'h0;
			ds_instruction <= 32'h0;
			ds_long_latency <= 1'h0;
			ds_op1_is_vector <= 1'h0;
			ds_pc <= 32'h0;
			ds_reg_lane_select <= 4'h0;
			ds_scalar_sel1_l <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			ds_scalar_sel2_l <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			ds_store_value_is_vector <= 1'h0;
			ds_strand <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			ds_strided_offset <= 32'h0;
			ds_vector_sel1_l <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			ds_vector_sel2_l <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			ds_writeback_reg <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			// End of automatics
		end
		else
		begin
			ds_writeback_reg <= writeback_reg_nxt;
			ds_alu_op <= alu_op_nxt;
			ds_store_value_is_vector <= store_value_is_vector_nxt;
			ds_immediate_value <= immediate_nxt;
			ds_op1_is_vector <= op1_is_vector_nxt;
			ds_op2_src <= op2_src_nxt;
			ds_mask_src <= mask_src_nxt;
			ds_reg_lane_select <= ss_reg_lane_select;
			ds_pc <= ss_pc;	
			ds_strided_offset <= ss_strided_offset;
			ds_vector_sel1_l <= ds_vector_sel1;
			ds_vector_sel2_l <= ds_vector_sel2;
			ds_scalar_sel1_l <= ds_scalar_sel1;
			ds_scalar_sel2_l <= ds_scalar_sel2;
	
			if (rb_squash_ds)
			begin
				ds_instruction 			<= `NOP;
				ds_strand				<= 0;
				ds_branch_predicted		<= 0;
				ds_enable_scalar_writeback	<= 0;
				ds_enable_vector_writeback	<= 0;
				ds_long_latency <= 0;
			end
			else
			begin
				ds_instruction 			<= ss_instruction;
				ds_strand				<= ss_strand;
				ds_branch_predicted		<= ss_branch_predicted;
				ds_enable_scalar_writeback	<= has_writeback && !writeback_is_vector;
				ds_enable_vector_writeback	<= has_writeback && writeback_is_vector;
				ds_long_latency <= ss_long_latency;
			end
		end
	end
endmodule
