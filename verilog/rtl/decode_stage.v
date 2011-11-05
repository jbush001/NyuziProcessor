`include "../timescale.v"

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

module decode_stage(
	input					clk,
	input[31:0]				instruction_i,
	output reg[31:0]		instruction_o,
	input [31:0]			pc_i,
	output reg[31:0]		pc_o,
	output reg[31:0]		immediate_o,
	output reg[2:0]			mask_src_o,
	output reg				op1_is_vector_o,
	output reg[1:0]			op2_src_o,
	output reg				store_value_is_vector_o,
	output reg[4:0]			scalar_sel1_o,
	output reg[4:0]			scalar_sel2_o,
	output wire[4:0]		vector_sel1_o,
	output reg[4:0]			vector_sel2_o,
	output reg				has_writeback_o,
	output reg [4:0]		writeback_reg_o,
	output reg 				writeback_is_vector_o,
	output reg[5:0]			alu_op_o,
	input [3:0]				lane_select_i,
	output reg[3:0]			lane_select_o,
	input					flush_i);

	wire					is_fmt_a;
	wire					is_fmt_b;
	wire					is_fmt_c;
	wire					is_fmt_d;
	wire[2:0]				a_fmt_type;
	wire[1:0]				b_fmt_type;
	wire[3:0]				c_op_type;
	reg						writeback_is_vector_nxt;
	reg[5:0]				alu_op_nxt;
	wire					has_writeback_nxt;
	wire					store_value_is_vector_nxt;
	reg[31:0]				immediate_nxt;
	reg						op1_is_vector_nxt;
	reg[1:0]				op2_src_nxt;
	reg[2:0]				mask_src_nxt;
	wire[4:0]				writeback_reg_nxt;
	wire					is_vector_memory_transfer;
	wire[5:0]				a_opcode;
	wire[4:0]				b_opcode;
	
	initial
	begin
		instruction_o = 0;
		pc_o = 0;
		immediate_o = 0;
		mask_src_o = 0;
		op1_is_vector_o = 0;
		op2_src_o = 0;
		store_value_is_vector_o = 0;
		scalar_sel1_o = 0;
		scalar_sel2_o = 0;
		vector_sel2_o = 0;
		has_writeback_o = 0;
		writeback_reg_o = 0;
		writeback_is_vector_o = 0;
		alu_op_o = 0;
		lane_select_o = 0;
		writeback_is_vector_nxt = 0;
		alu_op_nxt = 0;
		immediate_nxt = 0;
		op1_is_vector_nxt = 0;
		op2_src_nxt = 0;
		mask_src_nxt = 0;
	end

	assign is_fmt_a = instruction_i[31:29] == 3'b110;	
	assign is_fmt_b = instruction_i[31] == 1'b0;	
	assign is_fmt_c = instruction_i[31:30] == 2'b10;	
	assign is_fmt_d = instruction_i[31:28] == 4'b1100;	
	assign a_fmt_type = instruction_i[22:20];
	assign b_fmt_type = instruction_i[25:24];
	assign c_op_type = instruction_i[28:25];
	assign is_vector_memory_transfer = c_op_type[3] == 1'b1 || c_op_type == 4'b0111
		|| c_op_type == 4'b0110;
	assign a_opcode = instruction_i[28:23];
	assign b_opcode = instruction_i[30:26];

	always @*
	begin
		if (is_fmt_b)
			immediate_nxt = { {23{instruction_i[23]}}, instruction_i[23:15] };
		else if (is_fmt_c || is_fmt_d)
			immediate_nxt = { {22{instruction_i[24]}}, instruction_i[24:15] };
		else // fmt_e
			immediate_nxt = { {11{instruction_i[25]}}, instruction_i[25:5] };
	end

	// Note that the register port selects are not registered, because the 
	// register file has one cycle of latency.  The registered outputs and 
	// the register fetch results will arrive at the same time to the
	// execute stage.

	// s1
	always @*
	begin
		if (is_fmt_a && (a_fmt_type == 3'b001 || a_fmt_type == 3'b010
			|| a_fmt_type == 3'b011))
		begin
			// A bit of a special case: since we are already using s2
			// to read the scalar operand, need to use s1 for the mask.
			scalar_sel1_o = instruction_i[14:10];
		end
		else
			scalar_sel1_o = instruction_i[4:0];
	end

	// s2
	always @*
	begin
		if (is_fmt_c && ~instruction_i[29] && !is_vector_memory_transfer)
			scalar_sel2_o = instruction_i[9:5];
		else if (is_fmt_a && (a_fmt_type == 3'b000 || a_fmt_type == 3'b001
			|| a_fmt_type == 3'b010 || a_fmt_type == 3'b011))
		begin
			scalar_sel2_o = instruction_i[19:15];	// src2
		end
		else
			scalar_sel2_o = instruction_i[14:10];	// mask
	end

	// v1
	assign vector_sel1_o = instruction_i[4:0];
	
	// v2
	always @*
	begin
		if (is_fmt_a && (a_fmt_type == 3'b100 || a_fmt_type == 3'b101
			|| a_fmt_type == 3'b110))
			vector_sel2_o = instruction_i[19:15];	// src2
		else
			vector_sel2_o = instruction_i[9:5];		// store value
	end

	// op1 type
	always @*
	begin
		if (is_fmt_a)
			op1_is_vector_nxt = a_fmt_type != 0;
		else if (is_fmt_b)
			op1_is_vector_nxt = b_fmt_type != 0;
		else if (is_fmt_c)
			op1_is_vector_nxt = c_op_type == 4'b1100 || c_op_type == 4'b1101
				|| c_op_type == 4'b1110;
		else
			op1_is_vector_nxt = 1'b0;
	end

	// The values for op2_src_o match those in execute_stage.v
	// (see op2_src_i case statement).
	always @*
	begin
		if (is_fmt_a)
		begin
			if (instruction_i[22])
				op2_src_nxt = 2'b01;	// Vector operand
			else
				op2_src_nxt = 2'b00;	// Scalar operand
		end
		else	// Format B or C or don't care
			op2_src_nxt = 2'b10;	// Immediate operand
	end
	
	// mask_src
	//  0 = scalar_value_1
	//  1 = ~scalar_value_1
	//  2 = scalar_value_2
	//  3 = ~scalar_value_2
	//  4 = all ones (no mask)
	always @*
	begin
		if (is_fmt_a)
		begin
			case (a_fmt_type)
				3'b000:	mask_src_nxt = 4;	// scalar/scalar
				3'b001: mask_src_nxt = 4; 	// vector/scalar
				3'b010: mask_src_nxt = 0;	// vector/scalar masked
				3'b011: mask_src_nxt = 1;	// vector/scalar invert mask
				3'b100: mask_src_nxt = 4;	// vector/vector
				3'b101: mask_src_nxt = 2;	// vector/vector masked
				3'b110: mask_src_nxt = 3;	// vector/vector invert mask
				3'b111: mask_src_nxt = 0;	// Mode is reserved
			endcase
		end
		else if (is_fmt_b)
		begin
			case (b_fmt_type)
				2'b00: mask_src_nxt = 4;	// scalar immediate
				2'b01: mask_src_nxt = 4;	// vector immediate
				2'b10: mask_src_nxt = 2;	// vector immediate masked
				2'b11: mask_src_nxt = 3;	// vector immediate invert mask
			endcase
		end
		else if (is_fmt_c)
		begin
			case (c_op_type)
				4'b0000: mask_src_nxt = 4;	// Scalar Access
				4'b0001: mask_src_nxt = 4;
				4'b0010: mask_src_nxt = 4;
				4'b0011: mask_src_nxt = 4;
				4'b0100: mask_src_nxt = 4;		
				4'b0101: mask_src_nxt = 4;			
				4'b0110: mask_src_nxt = 4;	// Block vector access
				4'b0111: mask_src_nxt = 2;
				4'b1000: mask_src_nxt = 3;
				4'b1001: mask_src_nxt = 4; 	// Strided vector access		
				4'b1010: mask_src_nxt = 2;
				4'b1011: mask_src_nxt = 3;
				4'b1100: mask_src_nxt = 4;	// Scatter/Gather			
				4'b1101: mask_src_nxt = 2;
				4'b1110: mask_src_nxt = 3;
				4'b1111: mask_src_nxt = 4;	// Reserved Mode
			endcase
		end
		else
			mask_src_nxt = 4;
	end
	
	assign store_value_is_vector_nxt = !(is_fmt_c && !is_vector_memory_transfer);

	always @*
	begin
		if (is_fmt_a)
			alu_op_nxt = instruction_i[28:23];
		else if (is_fmt_b)
			alu_op_nxt = instruction_i[30:26];
		else 
			alu_op_nxt = 6'b000101;	// Addition (for offsets)
	end

	// Decode writeback
	assign has_writeback_nxt = (is_fmt_a || is_fmt_b 
		|| (is_fmt_c && instruction_i[29])) && instruction_i != 0;	// XXX check for nop for debugging
	assign writeback_reg_nxt = instruction_i[9:5];

	always @*
	begin
		if (is_fmt_a)
		begin	
			if (a_opcode[5:4] == 2'b01 || a_opcode[5:2] == 4'b1011)
				writeback_is_vector_nxt = 0;	// compare op
			else
				writeback_is_vector_nxt = a_fmt_type != 3'b000;
		end
		else if (is_fmt_b)
		begin
			if (b_opcode[4] == 1'b1)
				writeback_is_vector_nxt = 0;	// compare op
			else
				writeback_is_vector_nxt = b_fmt_type != 2'b00;
		end
		else // is_fmt_c or don't care...
			writeback_is_vector_nxt = is_vector_memory_transfer;
	end

	always @(posedge clk)
	begin
		if (flush_i)
		begin
			instruction_o 				<= #1 0;
			writeback_is_vector_o 		<= #1 0;
			alu_op_o 					<= #1 0;
			has_writeback_o				<= #1 0;
			store_value_is_vector_o 	<= #1 0;
			immediate_o					<= #1 0;
			op1_is_vector_o				<= #1 0;
			op2_src_o					<= #1 0;
			mask_src_o					<= #1 0;
			lane_select_o				<= #1 0;
			writeback_reg_o				<= #1 0;
			pc_o						<= #1 0;
		end
		else
		begin
			instruction_o 				<= #1 instruction_i;
			writeback_is_vector_o 		<= #1 writeback_is_vector_nxt;
			alu_op_o 					<= #1 alu_op_nxt;
			has_writeback_o				<= #1 has_writeback_nxt;
			store_value_is_vector_o 	<= #1 store_value_is_vector_nxt;
			immediate_o					<= #1 immediate_nxt;
			op1_is_vector_o				<= #1 op1_is_vector_nxt;
			op2_src_o					<= #1 op2_src_nxt;
			mask_src_o					<= #1 mask_src_nxt;
			lane_select_o				<= #1 lane_select_i;
			writeback_reg_o				<= #1 writeback_reg_nxt;
			pc_o						<= #1 pc_i;		
		end
	end
endmodule
