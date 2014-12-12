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
// Instruction Pipeline - Instruction Decode Stage
// Populate the decoded_instruction_t structure with fields from
// the instruction. The structure contains control fields will be 
// used later in the pipeline.
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
// | C - scatter/gather|   v1  |  imm  |  s2   |  v2   |
// | D                 |   s1  |  imm  |       |       |
// | E                 |   s1  |       |       |       |
// +-------------------+-------+-------+-------+-------+
//

module instruction_decode_stage(
	input                         clk,
	input                         reset,
	
	// From instruction fetch data stage
	input scalar_t                ifd_instruction,
	input                         ifd_instruction_valid,
	input scalar_t                ifd_pc,
	input thread_idx_t            ifd_thread_idx,

	// To thread select stage
	output decoded_instruction_t  id_instruction,
	output logic                  id_instruction_valid,
	output thread_idx_t           id_thread_idx,
	
	// From rollback controller
	input                         wb_rollback_en,
	input thread_idx_t            wb_rollback_thread_idx);

	localparam T = 1'b1;
	localparam F = 1'b0;

	typedef enum logic[2:0] {
		IMM_DONT_CARE,
		IMM_B_NARROW,
		IMM_B_WIDE,
		IMM_C_NARROW,
		IMM_C_WIDE,
		IMM_E
	} imm_loc_t;
	
	typedef enum logic[1:0] {
		SCLR1_NONE,	
		SCLR1_14_10,
		SCLR1_4_0
	} scalar1_loc_t;

	typedef enum logic[2:0] {
		SCLR2_NONE,
		SCLR2_19_15,
		SCLR2_14_10,
		SCLR2_9_5,
		SCLR2_PC
	} scalar2_loc_t;

	struct packed {
		logic illegal;
		logic dest_is_vector;
		logic has_dest;
		imm_loc_t imm_loc;
		scalar1_loc_t scalar1_loc;
		scalar2_loc_t scalar2_loc;
		logic has_vector1;
		logic has_vector2;
		logic vector_sel2_is_9_5;	// Else is src2.  Only for stores.
		logic op1_is_vector;
		op2_src_t op2_src;
		mask_src_t mask_src;
		logic store_value_is_vector;
		logic is_call;
	} dlut_out;

	decoded_instruction_t decoded_instr_nxt;
	logic is_nop;
	logic is_fmt_a;
	logic is_fmt_b;
	logic is_getlane;
	logic is_compare;
	alu_op_t alu_op;
	fmtc_op_t memory_access_type;
	register_idx_t scalar_sel2;

	// The instruction set has been structured so that the format of the instruction
	// can be determined from the first 7 bits. Those are fed into this ROM table that sets
	// the decoded information.
	always_comb
	begin
		casez (ifd_instruction[31:25])
			// Format A
			7'b110_000_?: dlut_out = { F, F, T, IMM_DONT_CARE, SCLR1_4_0, SCLR2_19_15, F, F, F, F, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, F };
			7'b110_001_?: dlut_out = { F, T, T, IMM_DONT_CARE, SCLR1_4_0, SCLR2_19_15, T, F, F, T, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, F };
			7'b110_010_?: dlut_out = { F, T, T, IMM_DONT_CARE, SCLR1_14_10, SCLR2_19_15, T, F, F, T, OP2_SRC_SCALAR2, MASK_SRC_SCALAR1, F, F };
			7'b110_100_?: dlut_out = { F, T, T, IMM_DONT_CARE, SCLR1_14_10, SCLR2_NONE,   T, T, F, T, OP2_SRC_VECTOR2, MASK_SRC_ALL_ONES, F, F };
			7'b110_101_?: dlut_out = { F, T, T, IMM_DONT_CARE, SCLR1_4_0, SCLR2_14_10, T, T, F, T, OP2_SRC_VECTOR2, MASK_SRC_SCALAR2, F, F };

			// Format B
			7'b0_000_???: dlut_out = { F, F, T, IMM_B_WIDE, SCLR1_4_0, SCLR2_NONE,      F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b0_001_???: dlut_out = { F, T, T, IMM_B_WIDE, SCLR1_4_0, SCLR2_NONE,      T, F, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b0_010_???: dlut_out = { F, T, T, IMM_B_NARROW, SCLR1_4_0, SCLR2_14_10,  T, F, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F, F };
			7'b0_100_???: dlut_out = { F, T, T, IMM_B_WIDE, SCLR1_4_0, SCLR2_NONE,      F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b0_101_???: dlut_out = { F, T, T, IMM_B_NARROW, SCLR1_4_0, SCLR2_14_10,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F, F };
			
			// Format C
			// Store
			7'b10_0_0000: dlut_out = { F, F, F, IMM_C_WIDE, SCLR1_4_0, SCLR2_9_5,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_0_0001: dlut_out = { F, F, F, IMM_C_WIDE, SCLR1_4_0, SCLR2_9_5,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_0_0010: dlut_out = { F, F, F, IMM_C_WIDE, SCLR1_4_0, SCLR2_9_5,   T, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_0_0011: dlut_out = { F, F, F, IMM_C_WIDE, SCLR1_4_0, SCLR2_9_5,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_0_0100: dlut_out = { F, F, F, IMM_C_WIDE, SCLR1_4_0, SCLR2_9_5,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_0_0101: dlut_out = { F, F, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_9_5,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_0_0110: dlut_out = { F, F, F, IMM_C_WIDE, SCLR1_4_0, SCLR2_9_5,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_0_0111: dlut_out = { F, F, F, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, T, F };
			7'b10_0_1000: dlut_out = { F, F, F, IMM_C_NARROW, SCLR1_4_0, SCLR2_14_10,    F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, T, F };
			7'b10_0_1101: dlut_out = { F, F, F, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, T, T, T, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, T, F };
			7'b10_0_1110: dlut_out = { F, F, F, IMM_C_NARROW, SCLR1_4_0, SCLR2_14_10,    T, T, T, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, T, F };

			// Load
			7'b10_1_0000: dlut_out = { F, F, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_1_0001: dlut_out = { F, F, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_1_0010: dlut_out = { F, F, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_1_0011: dlut_out = { F, F, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_1_0100: dlut_out = { F, F, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_1_0101: dlut_out = { F, F, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_1_0110: dlut_out = { F, F, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_1_0111: dlut_out = { F, T, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_1_1000: dlut_out = { F, T, T, IMM_C_NARROW, SCLR1_4_0, SCLR2_14_10,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F, F };
			7'b10_1_1101: dlut_out = { F, T, T, IMM_C_WIDE, SCLR1_4_0, SCLR2_NONE,      T, T, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b10_1_1110: dlut_out = { F, T, T, IMM_C_NARROW, SCLR1_4_0, SCLR2_14_10,    T, T, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F, F };
			
			// Format D
			7'b1110_000: dlut_out = { F, F, F,  IMM_C_NARROW, SCLR1_4_0, SCLR2_NONE,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b1110_001: dlut_out = { F, F, F,  IMM_C_NARROW, SCLR1_4_0, SCLR2_NONE,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b1110_010: dlut_out = { F, F, F,  IMM_C_NARROW, SCLR1_4_0, SCLR2_NONE,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b1110_011: dlut_out = { F, F, F,  IMM_C_NARROW, SCLR1_4_0, SCLR2_NONE,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b1110_100: dlut_out = { F, F, F,  IMM_C_NARROW, SCLR1_NONE, SCLR2_NONE,      F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			
			// Format E
			7'b1111_000: dlut_out = { F, F, F, IMM_E, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b1111_001: dlut_out = { F, F, F, IMM_E, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b1111_010: dlut_out = { F, F, F, IMM_E, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b1111_011: dlut_out = { F, F, F, IMM_E, SCLR1_NONE, SCLR2_NONE,     F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b1111_100: dlut_out = { F, F, T, IMM_E, SCLR1_NONE, SCLR2_PC,     F, F, F, F, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, T };
			7'b1111_101: dlut_out = { F, F, F, IMM_E, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
			7'b1111_110: dlut_out = { F, F, T, IMM_E, SCLR1_4_0, SCLR2_PC,   F, F, F, F, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, T };
			7'b1111_111: dlut_out = { F, F, T, IMM_E, SCLR1_4_0, SCLR2_PC,   F, F, F, F, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, F };

			// Invalid instruction format
			default: dlut_out = { T, F, F, IMM_DONT_CARE, SCLR1_NONE, SCLR2_NONE, F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F };
		endcase
	end
	
	assign is_fmt_a = ifd_instruction[31:29] == 3'b110;
	assign is_fmt_b = ifd_instruction[31] == 1'b0;
	assign is_getlane = (is_fmt_a || is_fmt_b) && alu_op == OP_GETLANE;
	
	assign is_nop = ifd_instruction == 0;
	
	assign decoded_instr_nxt.illegal = dlut_out.illegal;
	assign decoded_instr_nxt.has_scalar1 = dlut_out.scalar1_loc != SCLR1_NONE && !is_nop;
	always_comb 
	begin
		unique case (dlut_out.scalar1_loc)
			SCLR1_14_10:  decoded_instr_nxt.scalar_sel1 = ifd_instruction[14:10];
			default:   decoded_instr_nxt.scalar_sel1 = ifd_instruction[4:0]; //  src1
		endcase
	end

	assign decoded_instr_nxt.has_scalar2 = dlut_out.scalar2_loc != SCLR2_NONE && !is_nop;

	// XXX: assigning this directly to decoded_instr_nxt.scalar_sel2 causes Verilator issues when
	// other blocks read it. Added another signal to work around this.
	always_comb 
	begin
		unique case (dlut_out.scalar2_loc)
			SCLR2_14_10: scalar_sel2 = ifd_instruction[14:10];	
			SCLR2_19_15: scalar_sel2 = ifd_instruction[19:15];
			SCLR2_9_5: scalar_sel2 = ifd_instruction[9:5];
			SCLR2_PC: scalar_sel2 = `REG_PC;
			default: scalar_sel2 = 0;
		endcase
	end
	
	assign decoded_instr_nxt.scalar_sel2 = scalar_sel2;
	assign decoded_instr_nxt.has_vector1 = dlut_out.has_vector1 && !is_nop;
	assign decoded_instr_nxt.vector_sel1 = ifd_instruction[4:0];
	assign decoded_instr_nxt.has_vector2 = dlut_out.has_vector2 && !is_nop;
	always_comb
	begin
		if (dlut_out.vector_sel2_is_9_5)
			decoded_instr_nxt.vector_sel2 = ifd_instruction[9:5];
		else
			decoded_instr_nxt.vector_sel2 = ifd_instruction[19:15];
	end

	assign decoded_instr_nxt.has_dest = dlut_out.has_dest && !is_nop;
	
	assign decoded_instr_nxt.dest_is_vector = dlut_out.dest_is_vector && !is_compare
		&& !is_getlane;
	assign decoded_instr_nxt.dest_reg = dlut_out.is_call ? `REG_RA : ifd_instruction[9:5];
	always_comb
	begin
		if (is_fmt_b)
			alu_op = alu_op_t'({ 1'b0, ifd_instruction[27:23] });	// Format B
		else if (dlut_out.is_call)
			alu_op = OP_MOVE;	// Treat a call as move ra, pc
		else
			alu_op = alu_op_t'(ifd_instruction[25:20]); // Format A
	end

	assign decoded_instr_nxt.alu_op = alu_op;
	assign decoded_instr_nxt.mask_src = dlut_out.mask_src;
	assign decoded_instr_nxt.store_value_is_vector = dlut_out.store_value_is_vector;

	// Decode operand source ports, checking specifically for PC operands
	always_comb
	begin
		if (dlut_out.op1_is_vector)
			decoded_instr_nxt.op1_src = OP1_SRC_VECTOR1;
		else if (decoded_instr_nxt.scalar_sel1 == `REG_PC)
			decoded_instr_nxt.op1_src = OP1_SRC_PC;
		else
			decoded_instr_nxt.op1_src = OP1_SRC_SCALAR1;
			
		if (dlut_out.op2_src == OP2_SRC_SCALAR2 && scalar_sel2 == `REG_PC)
			decoded_instr_nxt.op2_src = OP2_SRC_PC;
		else
			decoded_instr_nxt.op2_src = dlut_out.op2_src;
	end

	always_comb
	begin
		unique case (dlut_out.imm_loc)
			IMM_B_NARROW:  decoded_instr_nxt.immediate_value = { {24{ifd_instruction[22]}}, ifd_instruction[22:15] };
			IMM_B_WIDE:    decoded_instr_nxt.immediate_value = { {19{ifd_instruction[22]}}, ifd_instruction[22:10] };
			IMM_C_NARROW:  decoded_instr_nxt.immediate_value = { {22{ifd_instruction[24]}}, ifd_instruction[24:15] };
			IMM_C_WIDE:    decoded_instr_nxt.immediate_value = { {17{ifd_instruction[24]}}, ifd_instruction[24:10] };
			IMM_E:         decoded_instr_nxt.immediate_value = { {12{ifd_instruction[24]}}, ifd_instruction[24:5] };
			default:       decoded_instr_nxt.immediate_value = 0;
		endcase
	end

	assign decoded_instr_nxt.branch_type = branch_type_t'(ifd_instruction[27:25]);
	assign decoded_instr_nxt.is_branch = ifd_instruction[31:28] == 4'b1111;
	assign decoded_instr_nxt.pc = ifd_pc;
	
	always_comb
	begin
		if (dlut_out.illegal)
			decoded_instr_nxt.pipeline_sel = PIPE_SCYCLE_ARITH;
		else if (is_fmt_a || is_fmt_b)
		begin
			if (alu_op[5] || alu_op == OP_MULL_I || alu_op == OP_MULH_U 
				 || alu_op == OP_MULH_I || alu_op == OP_FTOI || alu_op == OP_ITOF)
				decoded_instr_nxt.pipeline_sel = PIPE_MCYCLE_ARITH;
			else
				decoded_instr_nxt.pipeline_sel = PIPE_SCYCLE_ARITH;
		end
		else if (ifd_instruction[31:28] == 4'b1111)
			decoded_instr_nxt.pipeline_sel = PIPE_SCYCLE_ARITH;	// branches are evaluated in single cycle pipeline
		else
			decoded_instr_nxt.pipeline_sel = PIPE_MEM;	
	end
	
	assign memory_access_type = fmtc_op_t'(ifd_instruction[28:25]);
	assign decoded_instr_nxt.memory_access_type = memory_access_type;
	assign decoded_instr_nxt.is_memory_access = ifd_instruction[31:30] == 2'b10;
	assign decoded_instr_nxt.is_load = ifd_instruction[29];
	assign decoded_instr_nxt.is_cache_control = ifd_instruction[31:28] == 4'b1110;
	assign decoded_instr_nxt.cache_control_op = fmtd_op_t'(ifd_instruction[27:25]);
	
	always_comb
	begin
		if (ifd_instruction[31:30] == 2'b10
			&& (memory_access_type == MEM_SCGATH
			|| memory_access_type == MEM_SCGATH_M))
		begin
			// Scatter/Gather access
			decoded_instr_nxt.last_subcycle = `VECTOR_LANES - 1;
		end
		else
			decoded_instr_nxt.last_subcycle = 0;
	end

	assign decoded_instr_nxt.creg_index = control_register_t'(ifd_instruction[4:0]);
	
	assign is_compare = (is_fmt_a || is_fmt_b)
		&& (alu_op == OP_CMPEQ_I
		|| alu_op == OP_CMPNE_I
		|| alu_op == OP_CMPGT_I
		|| alu_op == OP_CMPGE_I
		|| alu_op == OP_CMPLT_I
		|| alu_op == OP_CMPLE_I
		|| alu_op == OP_CMPGT_U
		|| alu_op == OP_CMPGE_U
		|| alu_op == OP_CMPLT_U
		|| alu_op == OP_CMPLE_U
		|| alu_op == OP_CMPGT_F
		|| alu_op == OP_CMPLT_F
		|| alu_op == OP_CMPGE_F
		|| alu_op == OP_CMPLE_F
		|| alu_op == OP_CMPEQ_F
		|| alu_op == OP_CMPNE_F);
	assign decoded_instr_nxt.is_compare = is_compare;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			id_instruction <= 0;
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			id_instruction_valid <= 1'h0;
			id_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			id_instruction_valid <= ifd_instruction_valid && (!wb_rollback_en || wb_rollback_thread_idx != ifd_thread_idx);
			id_instruction <= decoded_instr_nxt;
			id_thread_idx <= ifd_thread_idx;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

