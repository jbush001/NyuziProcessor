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
// Instruction Pipeline - Instruction Decode Stage
// - Determine which register operands the instruction has
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

	decoded_instruction_t decoded_instr_nxt;
	logic is_nop;
	
	typedef enum logic[2:0] {
		IMM_DONT_CARE,
		IMM_B_NARROW,
		IMM_B_WIDE,
		IMM_C_NARROW,
		IMM_C_WIDE,
		IMM_E
	} imm_loc_t;
	
	typedef enum logic[1:0] {
		SC1_NU,	// Not used
		SC1_MASK,
		SC1_SRC1
	} scalar1_loc_t;

	typedef enum logic[1:0] {
		SC2_NU,	// Not used
		SC2_SRC2,
		SC2_MASK,
		SC2_STVAL
	} scalar2_loc_t;

	struct packed {
		logic invalid_instr;
		logic dest_is_vector;
		logic has_dest;
		imm_loc_t imm_loc;
		scalar1_loc_t scalar1_loc;
		scalar2_loc_t scalar2_loc;
		logic has_vector1;
		logic has_vector2;
		logic vector_sel2_is_dest;	// Else is src2.  Only for stores.
		logic op1_is_vector;
		op2_src_t op2_src;
		mask_src_t mask_src;
		logic store_value_is_vector;
	} dlut_out;
	
	localparam T = 1'b1;
	localparam F = 1'b0;

	// The instruction set has been structured so that the format of the instruction
	// can be determined from the first 7 bits. Those are fed into this ROM table that sets
	// the decoded information.
	always_comb
	begin
		casez (ifd_instruction[31:25])
			// Format A
			7'b110_000_?: dlut_out = { F, F, T, IMM_DONT_CARE, SC1_SRC1, SC2_SRC2, F, F, F, F, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F };
			7'b110_001_?: dlut_out = { F, T, T, IMM_DONT_CARE, SC1_SRC1, SC2_SRC2, T, F, F, T, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F };
			7'b110_010_?: dlut_out = { F, T, T, IMM_DONT_CARE, SC1_MASK, SC2_SRC2, T, F, F, T, OP2_SRC_SCALAR2, MASK_SRC_SCALAR1, F };
			7'b110_011_?: dlut_out = { F, T, T, IMM_DONT_CARE, SC1_MASK, SC2_SRC2, T, F, F, T, OP2_SRC_SCALAR2, MASK_SRC_SCALAR1_INV, F };
			7'b110_100_?: dlut_out = { F, T, T, IMM_DONT_CARE, SC1_MASK, SC2_NU,   T, T, F, T, OP2_SRC_VECTOR2, MASK_SRC_ALL_ONES, F };
			7'b110_101_?: dlut_out = { F, T, T, IMM_DONT_CARE, SC1_SRC1, SC2_MASK, T, T, F, T, OP2_SRC_VECTOR2, MASK_SRC_SCALAR2, F };
			7'b110_110_?: dlut_out = { F, T, T, IMM_DONT_CARE, SC1_SRC1, SC2_MASK, T, T, F, T, OP2_SRC_VECTOR2, MASK_SRC_SCALAR2_INV, F };

			// Format B
			7'b0_000_???: dlut_out = { F, F, T, IMM_B_WIDE, SC1_SRC1, SC2_NU,      F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b0_001_???: dlut_out = { F, T, T, IMM_B_WIDE, SC1_SRC1, SC2_NU,      T, F, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b0_010_???: dlut_out = { F, T, T, IMM_B_NARROW, SC1_SRC1, SC2_MASK,  T, F, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F };
			7'b0_011_???: dlut_out = { F, T, T, IMM_B_NARROW, SC1_SRC1, SC2_NU,    T, F, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2_INV, F };
			7'b0_100_???: dlut_out = { F, T, T, IMM_B_WIDE, SC1_SRC1, SC2_NU,      F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b0_101_???: dlut_out = { F, T, T, IMM_B_NARROW, SC1_SRC1, SC2_NU,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F };
			7'b0_110_???: dlut_out = { F, T, T, IMM_B_NARROW, SC1_SRC1, SC2_NU,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2_INV, F };
			
			// Format C
			// Store
			7'b10_0_0000: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_STVAL,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_0_0001: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_STVAL,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_0_0010: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_STVAL,   T, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_0_0011: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_STVAL,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_0_0100: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_STVAL,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_0_0101: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_STVAL,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_0_0110: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_STVAL,   F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_0_0111: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_NU,      F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, T };
			7'b10_0_1000: dlut_out = { F, F, F, IMM_C_NARROW, SC1_SRC1, SC2_NU,    F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, T };
			7'b10_0_1001: dlut_out = { F, F, F, IMM_C_NARROW, SC1_SRC1, SC2_NU,    F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2_INV, T };
			7'b10_0_1010: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_NU,      F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, T };
			7'b10_0_1011: dlut_out = { F, F, F, IMM_C_NARROW, SC1_SRC1, SC2_NU,    F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, T };
			7'b10_0_1100: dlut_out = { F, F, F, IMM_C_NARROW, SC1_SRC1, SC2_NU,    F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2_INV, T };
			7'b10_0_1101: dlut_out = { F, F, F, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, T, T, T, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, T };
			7'b10_0_1110: dlut_out = { F, F, F, IMM_C_NARROW, SC1_SRC1, SC2_NU,    T, T, T, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, T };
			7'b10_0_1111: dlut_out = { F, F, F, IMM_C_NARROW, SC1_SRC1, SC2_NU,    T, T, T, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2_INV, T };

			// Load
			7'b10_1_0000: dlut_out = { F, F, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_0001: dlut_out = { F, F, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_0010: dlut_out = { F, F, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_0011: dlut_out = { F, F, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_0100: dlut_out = { F, F, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_0101: dlut_out = { F, F, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_0110: dlut_out = { F, F, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_0111: dlut_out = { F, T, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_1000: dlut_out = { F, T, T, IMM_C_NARROW, SC1_SRC1, SC2_NU,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F };
			7'b10_1_1001: dlut_out = { F, T, T, IMM_C_NARROW, SC1_SRC1, SC2_NU,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2_INV, F };
			7'b10_1_1010: dlut_out = { F, T, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_1011: dlut_out = { F, T, T, IMM_C_NARROW, SC1_SRC1, SC2_NU,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F };
			7'b10_1_1100: dlut_out = { F, T, T, IMM_C_NARROW, SC1_SRC1, SC2_NU,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2_INV, F };
			7'b10_1_1101: dlut_out = { F, T, T, IMM_C_WIDE, SC1_SRC1, SC2_NU,      T, T, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b10_1_1110: dlut_out = { F, T, T, IMM_C_NARROW, SC1_SRC1, SC2_NU,    T, T, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F };
			7'b10_1_1111: dlut_out = { F, T, T, IMM_C_NARROW, SC1_SRC1, SC2_NU,    T, T, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2_INV, F };
			
			// Format D
			7'b1110_000: dlut_out = { F, F, T,  IMM_C_NARROW, SC1_SRC1, SC2_NU,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1110_001: dlut_out = { F, F, T,  IMM_C_NARROW, SC1_SRC1, SC2_NU,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1110_010: dlut_out = { F, F, T,  IMM_C_NARROW, SC1_SRC1, SC2_NU,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1110_011: dlut_out = { F, F, T,  IMM_C_NARROW, SC1_SRC1, SC2_NU,    F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1110_100: dlut_out = { F, F, T,  IMM_C_NARROW, SC1_NU, SC2_NU,      F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			
			// Format E
			7'b1111_000: dlut_out = { F, F, F, IMM_E, SC1_SRC1, SC2_NU,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1111_001: dlut_out = { F, F, F, IMM_E, SC1_SRC1, SC2_NU,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1111_010: dlut_out = { F, F, F, IMM_E, SC1_SRC1, SC2_NU,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1111_011: dlut_out = { F, F, F, IMM_E, SC1_NU, SC2_NU,     F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1111_100: dlut_out = { F, F, F, IMM_E, SC1_NU, SC2_NU,     F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1111_101: dlut_out = { F, F, F, IMM_E, SC1_SRC1, SC2_NU,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
			7'b1111_110: dlut_out = { F, F, F, IMM_E, SC1_SRC1, SC2_NU,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };

			// Invalid instruction format
			default: dlut_out = { T, F, F, IMM_DONT_CARE, SC1_NU, SC2_NU, F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F };
		endcase
	end
	
	assign is_nop = ifd_instruction == 0;
	
	assign decoded_instr_nxt.invalid_instr = dlut_out.invalid_instr;
	assign decoded_instr_nxt.has_scalar1 = dlut_out.scalar1_loc != SC1_NU && !is_nop;
	always_comb 
	begin
		unique case (dlut_out.scalar1_loc)
			SC1_MASK:  decoded_instr_nxt.scalar_sel1 = ifd_instruction[14:10];
			default:   decoded_instr_nxt.scalar_sel1 = ifd_instruction[4:0]; //  src1
		endcase
	end

	assign decoded_instr_nxt.has_scalar2 = dlut_out.scalar2_loc != SC2_NU && !is_nop;
	always_comb 
	begin
		unique case (dlut_out.scalar2_loc)
			SC2_MASK:  decoded_instr_nxt.scalar_sel2 = ifd_instruction[14:10];	
			SC2_SRC2:  decoded_instr_nxt.scalar_sel2 = ifd_instruction[19:15];
			SC2_STVAL: decoded_instr_nxt.scalar_sel2 = ifd_instruction[9:5];
			default:   decoded_instr_nxt.scalar_sel2 = 0;
		endcase
	end

	assign decoded_instr_nxt.has_vector1 = dlut_out.has_vector1 && !is_nop;
	assign decoded_instr_nxt.vector_sel1 = ifd_instruction[4:0];
	assign decoded_instr_nxt.has_vector2 = dlut_out.has_vector2 && !is_nop;
	always_comb
	begin
		if (dlut_out.vector_sel2_is_dest)
			decoded_instr_nxt.vector_sel2 = ifd_instruction[9:5];
		else
			decoded_instr_nxt.vector_sel2 = ifd_instruction[19:15];
	end

	assign decoded_instr_nxt.has_dest = dlut_out.has_dest && !is_nop;
	
	// XXX is_vector_compare is a slow path, since it depends on the decoded instruction
	assign decoded_instr_nxt.dest_is_vector = dlut_out.dest_is_vector && !decoded_instr_nxt.is_vector_compare;
	assign decoded_instr_nxt.dest_reg = ifd_instruction[9:5];
	always_comb
	begin
		if (ifd_instruction[31] == 0)
			decoded_instr_nxt.alu_op = alu_op_t'({ 1'b0, ifd_instruction[27:23] });	// Format B
		else
			decoded_instr_nxt.alu_op = alu_op_t'(ifd_instruction[25:20]); // Format A
	end

	assign decoded_instr_nxt.mask_src = dlut_out.mask_src;
	assign decoded_instr_nxt.op1_is_vector = dlut_out.op1_is_vector;
	assign decoded_instr_nxt.op2_src = dlut_out.op2_src;
	assign decoded_instr_nxt.store_value_is_vector = dlut_out.store_value_is_vector;
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
	
	// XXX this is the slowest part of the decoder because it depends on an already-decoded value
	// (decoded_instr_nxt.alu_op), which has already also had to go through a multiplexer to select the bits.
	// This is really an issue with the design of the instruction set.
	always_comb
	begin
		if (ifd_instruction[31:29] == 3'b110 || ifd_instruction[31] == 0)
		begin
			if (decoded_instr_nxt.alu_op[5] || decoded_instr_nxt.alu_op == OP_IMUL)
				decoded_instr_nxt.pipeline_sel = PIPE_MCYCLE_ARITH;
			else
				decoded_instr_nxt.pipeline_sel = PIPE_SCYCLE_ARITH;
		end
		else if (ifd_instruction[31:28] == 4'b1111)
			decoded_instr_nxt.pipeline_sel = PIPE_SCYCLE_ARITH;	// branches are evaluated in single cycle pipeline
		else
			decoded_instr_nxt.pipeline_sel = PIPE_MEM;	
	end
	
	assign decoded_instr_nxt.memory_access_type = fmtc_op_t'(ifd_instruction[28:25]);
	assign decoded_instr_nxt.is_memory_access = ifd_instruction[31:30] == 2'b10;
	assign decoded_instr_nxt.is_load = ifd_instruction[29];
	
	always_comb
	begin
		if (ifd_instruction[31:30] == 2'b10
			&& (decoded_instr_nxt.memory_access_type == MEM_SCGATH
			|| decoded_instr_nxt.memory_access_type == MEM_SCGATH_M
			|| decoded_instr_nxt.memory_access_type == MEM_SCGATH_IM))
		begin
			// Scatter/Gather access
			decoded_instr_nxt.last_subcycle = `VECTOR_LANES - 1;
		end
		else
			decoded_instr_nxt.last_subcycle = 0;
	end

	// Set is_vector_compare. In vector compares, we need to form a mask with the result.
	always_comb
	begin
		decoded_instr_nxt.is_vector_compare = 0;
		if (ifd_instruction[31:29] == 3'b110 || ifd_instruction[31] == 0)
		begin
			// Is format A or B
			case (decoded_instr_nxt.alu_op)
				OP_EQUAL,
				OP_NEQUAL,	
				OP_SIGTR,	
				OP_SIGTE,	
				OP_SILT,	
				OP_SILTE,	
				OP_UIGTR,	
				OP_UIGTE,	
				OP_UILT,	
				OP_UILTE:
					if (dlut_out.dest_is_vector)
						decoded_instr_nxt.is_vector_compare = 1; 
			endcase
		end
	end
	
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

