//
// Decode stage:
//  - Maps register addresses to register file ports and issues request to latter.
//  - Decodes writeback destination, which will be propagated down the pipeline
//    for bypassing.
//
// Register port to operand mapping:
//                                               store 
//                        op1     op2    mask    value
// +-------------------+-------+-------+-------+-------+
// | A - scalar/scalar |   s1  |   s2  |  n/a  |  n/a  |
// | A - vector/scalar |   v1  |   s2  |  s1*  |  n/a  |
// | A - vector/vector |   v1  |   v2  |  s2   |  n/a  |
// | B - scalar        |   s1  |  imm  |  n/a  |  n/a  |
// | B - vector        |   v1  |  imm  |  s2   |  n/a  |
// | C - scalar        |   s1  |  imm  |  n/a  |  s2   |
// | C - block         |   s1  |  imm  |  s2   |  v2   |
// | C - strided       |   s1  |  imm  |  s2   |  v2   |
// | C - scatter/gather|   v1  |  imm  |  s2   |  v2   |
// | D - tbd...        |       |       |       |       |
// | E -               |   s1  |       |       |       |
// +-------------------+-------+-------+-------+-------+
//

`include "instruction_format.h"
`include "decode.h"

module decode_stage(
	input					clk,
	input[31:0]				instruction_i,
	output reg[31:0]		instruction_o = 0,
	input[1:0]				strand_i,
	output reg[1:0]			strand_o = 0,
	input [31:0]			pc_i,
	output reg[31:0]		pc_o = 0,
	output reg[31:0]		immediate_o = 0,
	output reg[2:0]			mask_src_o = 0,
	output reg				op1_is_vector_o = 0,
	output reg[1:0]			op2_src_o = 0,
	output reg				store_value_is_vector_o = 0,
	output reg[6:0]			scalar_sel1_o = 0,
	output reg[6:0]			scalar_sel2_o = 0,
	output wire[6:0]		vector_sel1_o,
	output reg[6:0]			vector_sel2_o = 0,
	output reg				has_writeback_o = 0,
	output reg [6:0]		writeback_reg_o = 0,
	output reg 				writeback_is_vector_o = 0,
	output reg[5:0]			alu_op_o = 0,
	input [3:0]				reg_lane_select_i,
	output reg[3:0]			reg_lane_select_o,
	input					flush_i,
	input [31:0]			strided_offset_i,
	output reg[31:0]		strided_offset_o = 0);

	reg						writeback_is_vector_nxt = 0;
	reg[5:0]				alu_op_nxt = 0;
	reg[31:0]				immediate_nxt = 0;
	reg						op1_is_vector_nxt = 0;
	reg[1:0]				op2_src_nxt = 0;
	reg[2:0]				mask_src_nxt = 0;
	
	wire is_fmt_a = instruction_i[31:29] == 3'b110;	
	wire is_fmt_b = instruction_i[31] == 1'b0;	
	wire is_fmt_c = instruction_i[31:30] == 2'b10;	
	wire[2:0] a_fmt_type = instruction_i[22:20];
	wire[2:0] b_fmt_type = instruction_i[25:23];
	wire[3:0] c_op_type = instruction_i[28:25];
	wire is_vector_memory_transfer = c_op_type[3] == 1'b1 || c_op_type == `MEM_BLOCK;
	wire[5:0] a_opcode = instruction_i[28:23];
	wire[4:0] b_opcode = instruction_i[30:26];
	wire is_call = instruction_i[31:25] == 7'b1111100;
	wire is_load = instruction_i[29];	// Assumes is op c

	always @*
	begin
		if (is_fmt_b)
		begin
			if (b_fmt_type == `FMTB_V_V_M 
				|| b_fmt_type == `FMTB_V_V_IM 
				|| b_fmt_type == `FMTB_V_S_M 
				|| b_fmt_type == `FMTB_V_S_IM)
				immediate_nxt = { {24{instruction_i[22]}}, instruction_i[22:15] };
			else
				immediate_nxt = { {19{instruction_i[22]}}, instruction_i[22:10] };
		end
		else // Format C, format D or don't care
			immediate_nxt = { {22{instruction_i[24]}}, instruction_i[24:15] };
	end

	// Note that the register port selects are not registered, because the 
	// register file has one cycle of latency.  The registered outputs and 
	// the register fetch results will arrive at the same time to the
	// execute stage.

	// s1
	always @*
	begin
		if (is_fmt_a && (a_fmt_type == `FMTA_V_S 
			|| a_fmt_type == `FMTA_V_S_M
			|| a_fmt_type == `FMTA_V_S_IM))
		begin
			// A bit of a special case: since we are already using s2
			// to read the scalar operand, need to use s1 for the mask.
			scalar_sel1_o = { strand_i, instruction_i[14:10] };
		end
		else
			scalar_sel1_o = { strand_i, instruction_i[4:0] };
	end

	// s2
	always @*
	begin
		if (is_fmt_c && ~is_load && !is_vector_memory_transfer)
			scalar_sel2_o = { strand_i, instruction_i[9:5] };
		else if (is_fmt_a && (a_fmt_type == `FMTA_S 
			|| a_fmt_type == `FMTA_V_S
			|| a_fmt_type == `FMTA_V_S_M 
			|| a_fmt_type == `FMTA_V_S_IM))
		begin
			scalar_sel2_o = { strand_i, instruction_i[19:15] };	// src2
		end
		else
			scalar_sel2_o = { strand_i, instruction_i[14:10] };	// mask
	end

	// v1
	assign vector_sel1_o = { strand_i, instruction_i[4:0] };
	
	// v2
	always @*
	begin
		if (is_fmt_a && (a_fmt_type == `FMTA_V_V 
			|| a_fmt_type == `FMTA_V_V_M
			|| a_fmt_type == `FMTA_V_V_IM))
			vector_sel2_o = { strand_i, instruction_i[19:15] };	// src2
		else
			vector_sel2_o = { strand_i, instruction_i[9:5] }; // store value
	end
	
	// op1 type
	always @*
	begin
		if (is_fmt_a)
			op1_is_vector_nxt = a_fmt_type != `FMTA_S;
		else if (is_fmt_b)
		begin
			op1_is_vector_nxt = b_fmt_type == `FMTB_V_V
				|| b_fmt_type == `FMTB_V_V_M
				|| b_fmt_type == `FMTB_V_V_IM;
		end
		else if (is_fmt_c)
			op1_is_vector_nxt = c_op_type == `MEM_SCGATH 
				|| c_op_type == `MEM_SCGATH_M
				|| c_op_type == `MEM_SCGATH_IM;
		else
			op1_is_vector_nxt = 1'b0;
	end

	// op2_src
	always @*
	begin
		if (is_fmt_a)
		begin
			if (a_fmt_type == `FMTA_V_V
				|| a_fmt_type == `FMTA_V_V_M
				|| a_fmt_type == `FMTA_V_V_IM)
				op2_src_nxt = `OP2_SRC_VECTOR2;	// Vector operand
			else
				op2_src_nxt = `OP2_SRC_SCALAR2;	// Scalar operand
		end
		else	// Format B or C or don't care
			op2_src_nxt = `OP2_SRC_IMMEDIATE;	// Immediate operand
	end
	
	// mask_src
	always @*
	begin
		if (is_fmt_a)
		begin
			// Register arithmetic instructions
			case (a_fmt_type)
				`FMTA_S:		mask_src_nxt = `MASK_SRC_ALL_ONES;	
				`FMTA_V_S: 		mask_src_nxt = `MASK_SRC_ALL_ONES;
				`FMTA_V_S_M: 	mask_src_nxt = `MASK_SRC_SCALAR1;
				`FMTA_V_S_IM: 	mask_src_nxt = `MASK_SRC_SCALAR1_INV;
				`FMTA_V_V: 		mask_src_nxt = `MASK_SRC_ALL_ONES;
				`FMTA_V_V_M: 	mask_src_nxt = `MASK_SRC_SCALAR2;
				`FMTA_V_V_IM: 	mask_src_nxt = `MASK_SRC_SCALAR2_INV;
				default: 		mask_src_nxt = `MASK_SRC_SCALAR1; // Invalid type
			endcase
		end
		else if (is_fmt_b)
		begin
			// Immediate arithmetic instructions
			case (b_fmt_type)
				`FMTB_S_S: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	
				`FMTB_V_V: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	
				`FMTB_V_V_M: 	mask_src_nxt = `MASK_SRC_SCALAR2;	
				`FMTB_V_V_IM:	mask_src_nxt = `MASK_SRC_SCALAR2_INV;	
				`FMTB_V_S:		mask_src_nxt = `MASK_SRC_ALL_ONES;	
				`FMTB_V_S_M: 	mask_src_nxt = `MASK_SRC_SCALAR2;	
				`FMTB_V_S_IM: 	mask_src_nxt = `MASK_SRC_SCALAR2_INV;	
				default: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	// Invalid type
			endcase
		end
		else if (is_fmt_c)
		begin
			// Memory access
			case (c_op_type)
				`MEM_B: 			mask_src_nxt = `MASK_SRC_ALL_ONES;	// Scalar Access
				`MEM_BX: 			mask_src_nxt = `MASK_SRC_ALL_ONES;
				`MEM_S: 			mask_src_nxt = `MASK_SRC_ALL_ONES;
				`MEM_SX: 			mask_src_nxt = `MASK_SRC_ALL_ONES;
				`MEM_L: 			mask_src_nxt = `MASK_SRC_ALL_ONES;		
				`MEM_SYNC: 			mask_src_nxt = `MASK_SRC_ALL_ONES;	// synchronized
				`MEM_CONTROL_REG:	mask_src_nxt = `MASK_SRC_ALL_ONES;	// Control reigster transfer
				`MEM_BLOCK: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	// Block vector access
				`MEM_BLOCK_M: 		mask_src_nxt = `MASK_SRC_SCALAR2;
				`MEM_BLOCK_IM: 		mask_src_nxt = `MASK_SRC_SCALAR2_INV;
				`MEM_STRIDED: 		mask_src_nxt = `MASK_SRC_ALL_ONES; 	// Strided vector access		
				`MEM_STRIDED_M: 	mask_src_nxt = `MASK_SRC_SCALAR2;
				`MEM_STRIDED_IM: 	mask_src_nxt = `MASK_SRC_SCALAR2_INV;
				`MEM_SCGATH: 		mask_src_nxt = `MASK_SRC_ALL_ONES;	// Scatter/Gather			
				`MEM_SCGATH_M: 		mask_src_nxt = `MASK_SRC_SCALAR2;
				`MEM_SCGATH_IM: 	mask_src_nxt = `MASK_SRC_SCALAR2_INV;
			endcase
		end
		else
			mask_src_nxt = `MASK_SRC_ALL_ONES;
	end
	
	wire store_value_is_vector_nxt = !(is_fmt_c && !is_vector_memory_transfer);

	always @*
	begin
		if (is_fmt_a)
			alu_op_nxt = instruction_i[28:23];
		else if (is_fmt_b)
			alu_op_nxt = instruction_i[30:26];
		else 
			alu_op_nxt = `OP_IADD;	// Addition (for offsets)
	end

	// Decode writeback
	wire has_writeback_nxt = (is_fmt_a 
		|| is_fmt_b 
		|| (is_fmt_c && is_load) 		// Load
		|| (is_fmt_c && c_op_type == `MEM_SYNC)	// Synchronized load/store
		|| is_call)
		&& instruction_i != `NOP;	// XXX check for nop for debugging

	wire[6:0] writeback_reg_nxt = is_call ? { strand_i, `REG_LINK }
		: { strand_i, instruction_i[9:5] };

	always @*
	begin
		if (is_fmt_a)
		begin	
			if (a_opcode[5:4] == 2'b01 || a_opcode[5:2] == 4'b1011)
				writeback_is_vector_nxt = 0;	// compare op
			else
				writeback_is_vector_nxt = a_fmt_type != `FMTA_S;
		end
		else if (is_fmt_b)
		begin
			if (b_opcode[4] == 1'b1)
				writeback_is_vector_nxt = 0;	// compare op (a bit special)
			else
				writeback_is_vector_nxt = b_fmt_type != `FMTB_S_S;
		end
		else if (is_call)
			writeback_is_vector_nxt = 0;
		else // is_fmt_c or don't care...
			writeback_is_vector_nxt = is_vector_memory_transfer;
	end

	always @(posedge clk)
	begin
		writeback_is_vector_o 		<= #1 writeback_is_vector_nxt;
		alu_op_o 					<= #1 alu_op_nxt;
		store_value_is_vector_o 	<= #1 store_value_is_vector_nxt;
		immediate_o					<= #1 immediate_nxt;
		op1_is_vector_o				<= #1 op1_is_vector_nxt;
		op2_src_o					<= #1 op2_src_nxt;
		mask_src_o					<= #1 mask_src_nxt;
		reg_lane_select_o			<= #1 reg_lane_select_i;
		writeback_reg_o				<= #1 writeback_reg_nxt;
		pc_o						<= #1 pc_i;	
		strided_offset_o			<= #1 strided_offset_i;

		if (flush_i)
		begin
			instruction_o 				<= #1 `NOP;
			has_writeback_o				<= #1 0;
			strand_o					<= #1 0;
		end
		else
		begin
			instruction_o 				<= #1 instruction_i;
			has_writeback_o				<= #1 has_writeback_nxt;
			strand_o					<= #1 strand_i;
		end
	end
endmodule
