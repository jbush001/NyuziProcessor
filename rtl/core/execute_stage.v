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

`include "instruction_format.h"
`include "decode.h"

//
// CPU pipeline execute stage
// - Performs arithmetic operations
// - Detects branch mispredictions
// - Issues address to data cache for tag check
// - Handles bypassing of register results that have not been committed
//	   to register file yet.
//

module execute_stage(
	input					clk,
	input [31:0]			ds_instruction,
	output reg[31:0]		ex_instruction = `NOP,
	input					ds_branch_predicted,
	input[1:0]				ds_strand,
	output reg[1:0]			ex_strand = 0,
	input [31:0]			ds_pc,
	output reg[31:0]		ex_pc = 0,
	input [31:0]			scalar_value1,
	input [6:0]				scalar_sel1_l,
	input [31:0]			scalar_value2,
	input [6:0]				scalar_sel2_l,
	input [511:0]			vector_value1,
	input [6:0]				vector_sel1_l,
	input [511:0]			vector_value2,
	input [6:0]				vector_sel2_l,
	input [31:0]			ds_immediate_value,
	input [2:0]				ds_mask_src,
	input					ds_op1_is_vector,
	input [1:0]				ds_op2_src,
	input					ds_store_value_is_vector,
	output reg[511:0]		ex_store_value = 0,
	input					ds_has_writeback,
	input [6:0]				ds_writeback_reg,
	input					ds_writeback_is_vector,	
	output reg				ex_has_writeback = 0,
	output reg[6:0]			ex_writeback_reg = 0,
	output reg				ex_writeback_is_vector = 0,
	output reg[15:0]		ex_mask = 0,
	output reg[511:0]		ex_result = 0,
	input [5:0]				ds_alu_op,
	input [3:0]				ds_reg_lane_select,
	output reg[3:0]			ex_reg_lane_select = 0,
	input [6:0]				ma_writeback_reg,		// mem access stage
	input					ma_has_writeback,
	input					ma_writeback_is_vector,
	input [511:0]			ma_result,
	input [15:0]			ma_mask,
	input [6:0]				wb_writeback_reg,		// writeback stage
	input					wb_has_writeback,
	input					wb_writeback_is_vector,
	input [511:0]			wb_writeback_value,
	input [15:0]			wb_writeback_mask,
	input [6:0]				rf_writeback_reg,		// post writeback
	input					rf_has_writeback,
	input					rf_writeback_is_vector,
	input [511:0]			rf_writeback_value,
	input [15:0]			rf_writeback_mask,
	output 					ex_rollback_request,
	output [31:0]			ex_rollback_pc,
	input					squash_ex0,
	input					squash_ex1,
	input					squash_ex2,
	input					squash_ex3,
	output[1:0]				ex_strand1,
	output[1:0]				ex_strand2,
	output[1:0]				ex_strand3,
	input [31:0]			ds_strided_offset,
	output reg [31:0]		ex_strided_offset = 0,
	output reg [31:0]		ex_base_addr);
	
	reg[511:0]				operand2 = 0;
	wire[511:0]				single_cycle_result;
	wire[511:0]				multi_cycle_result;
	reg[15:0]				mask_val = 0;
	wire[511:0]				vector_value1_bypassed;
	wire[511:0]				vector_value2_bypassed;
	reg[31:0]				scalar_value1_bypassed = 0;
	reg[31:0]				scalar_value2_bypassed = 0;
	reg[31:0]				instruction_nxt = `NOP;
	reg[1:0]				strand_nxt = 0;
	reg						has_writeback_nxt;
	reg[6:0]				writeback_reg_nxt = 0;
	reg						writeback_is_vector_nxt = 0;
	reg[31:0]				pc_nxt = 0;
	reg[511:0]				result_nxt = 0;
	reg[15:0]				mask_nxt = 0;

	// Track instructions with multi-cycle latency.
	reg[31:0]				instruction1 = `NOP;
	reg[1:0]				strand1 = 0;
	reg[31:0]				pc1 = 0;
	reg						has_writeback1 = 0;
	reg[6:0]				writeback_reg1 = 0;
	reg						writeback_is_vector1 = 0;	
	reg[15:0]				mask1 = 0;
	reg[31:0]				instruction2 = `NOP;
	reg[1:0]				strand2 = 0;
	reg[31:0]				pc2 = 0;
	reg						has_writeback2 = 0;
	reg[6:0]				writeback_reg2 = 0;
	reg						writeback_is_vector2 = 0;	
	reg[15:0]				mask2 = 0;
	reg[31:0]				instruction3 = `NOP;
	reg[1:0]				strand3 = 0;
	reg[31:0]				pc3 = 0;
	reg						has_writeback3 = 0;
	reg[6:0]				writeback_reg3 = 0;
	reg						writeback_is_vector3 = 0;	
	reg[15:0]				mask3 = 0;
	wire[511:0]				shuffled;
	
	assign ex_strand1 = strand1;
	assign ex_strand2 = strand2;
	assign ex_strand3 = strand3;
	
	// Note: is_multi_cycle_latency must match the result computed in
	// strand select stage.
	wire is_fmt_a = ds_instruction[31:29] == 3'b110; 
	wire is_fmt_b = ds_instruction[31] == 1'b0;
	wire is_fmt_c = ds_instruction[31:30] == 2'b10;	
	wire is_fmt_e = ds_instruction[31:28] == 4'b1111;
	wire is_multi_cycle_latency = (is_fmt_a && ds_instruction[28] == 1)
		|| (is_fmt_a && ds_instruction[28:23] == `OP_IMUL)	
		|| (is_fmt_b && ds_instruction[30:26] == `OP_IMUL);	
	wire[2:0] branch_type = ds_instruction[27:25];
	wire is_call = is_fmt_e && (branch_type == `BRANCH_CALL_OFFSET
		|| branch_type == `BRANCH_CALL_REGISTER);
	wire[31:0] branch_offset = { {12{ds_instruction[24]}}, ds_instruction[24:5] };

	// scalar_value1_bypassed
	always @*
	begin
		if (scalar_sel1_l[4:0] == `REG_PC)
			scalar_value1_bypassed = ds_pc;
		else if (scalar_sel1_l == ex_writeback_reg && ex_has_writeback
			&& !ex_writeback_is_vector)
			scalar_value1_bypassed = ex_result[31:0];
		else if (scalar_sel1_l == ma_writeback_reg && ma_has_writeback
			&& !ma_writeback_is_vector)
			scalar_value1_bypassed = ma_result[31:0];
		else if (scalar_sel1_l == wb_writeback_reg && wb_has_writeback
			&& !wb_writeback_is_vector)
			scalar_value1_bypassed = wb_writeback_value[31:0];
		else if (scalar_sel1_l == rf_writeback_reg && rf_has_writeback
			&& !rf_writeback_is_vector)
			scalar_value1_bypassed = rf_writeback_value[31:0];
		else 
			scalar_value1_bypassed = scalar_value1;	
	end

	// scalar_value2_bypassed
	always @*
	begin
		if (scalar_sel2_l[4:0] == `REG_PC)
			scalar_value2_bypassed = ds_pc;
		else if (scalar_sel2_l == ex_writeback_reg && ex_has_writeback
			&& !ex_writeback_is_vector)
			scalar_value2_bypassed = ex_result[31:0];
		else if (scalar_sel2_l == ma_writeback_reg && ma_has_writeback
			&& !ma_writeback_is_vector)
			scalar_value2_bypassed = ma_result[31:0];
		else if (scalar_sel2_l == wb_writeback_reg && wb_has_writeback
			&& !wb_writeback_is_vector)
			scalar_value2_bypassed = wb_writeback_value[31:0];
		else if (scalar_sel2_l == rf_writeback_reg && rf_has_writeback
			&& !rf_writeback_is_vector)
			scalar_value2_bypassed = rf_writeback_value[31:0];
		else 
			scalar_value2_bypassed = scalar_value2;	
	end

	// vector_value1_bypassed
	vector_bypass_unit vbu1(
		.register_sel_i(vector_sel1_l), 
		.data_i(vector_value1),	
		.value_o(vector_value1_bypassed),
		.bypass1_register_i(ex_writeback_reg),	
		.bypass1_write_i(ex_has_writeback && ex_writeback_is_vector),
		.bypass1_value_i(ex_result),
		.bypass1_mask_i(ex_mask),
		.bypass2_register_i(ma_writeback_reg),	
		.bypass2_write_i(ma_has_writeback && ma_writeback_is_vector),
		.bypass2_value_i(ma_result),
		.bypass2_mask_i(ma_mask),
		.bypass3_register_i(wb_writeback_reg),	
		.bypass3_write_i(wb_has_writeback && wb_writeback_is_vector),
		.bypass3_value_i(wb_writeback_value),
		.bypass3_mask_i(wb_writeback_mask),
		.bypass4_register_i(rf_writeback_reg),	
		.bypass4_write_i(rf_has_writeback && rf_writeback_is_vector),
		.bypass4_value_i(rf_writeback_value),
		.bypass4_mask_i(rf_writeback_mask));

	// vector_value2_bypassed
	vector_bypass_unit vbu2(
		.register_sel_i(vector_sel2_l), 
		.data_i(vector_value2),	
		.value_o(vector_value2_bypassed),
		.bypass1_register_i(ex_writeback_reg),	
		.bypass1_write_i(ex_has_writeback && ex_writeback_is_vector),
		.bypass1_value_i(ex_result),
		.bypass1_mask_i(ex_mask),
		.bypass2_register_i(ma_writeback_reg),	
		.bypass2_write_i(ma_has_writeback && ma_writeback_is_vector),
		.bypass2_value_i(ma_result),
		.bypass2_mask_i(ma_mask),
		.bypass3_register_i(wb_writeback_reg),	
		.bypass3_write_i(wb_has_writeback && wb_writeback_is_vector),
		.bypass3_value_i(wb_writeback_value),
		.bypass3_mask_i(wb_writeback_mask),
		.bypass4_register_i(rf_writeback_reg),	
		.bypass4_write_i(rf_has_writeback && rf_writeback_is_vector),
		.bypass4_value_i(rf_writeback_value),
		.bypass4_mask_i(rf_writeback_mask));

	wire[511:0] operand1 = ds_op1_is_vector ? vector_value1_bypassed
		: {16{scalar_value1_bypassed}};

	// operand2
	always @*
	begin
		case (ds_op2_src)
			`OP2_SRC_SCALAR2:	operand2 = {16{scalar_value2_bypassed}};
			`OP2_SRC_VECTOR2:	operand2 = vector_value2_bypassed;
			`OP2_SRC_IMMEDIATE: operand2 = {16{ds_immediate_value}};
			default:			operand2 = {512{1'bx}}; // Don't care
		endcase
	end
	
	// mask
	always @*
	begin
		case (ds_mask_src)
			`MASK_SRC_SCALAR1:		mask_val = scalar_value1_bypassed[15:0];
			`MASK_SRC_SCALAR1_INV:	mask_val = ~scalar_value1_bypassed[15:0];
			`MASK_SRC_SCALAR2:		mask_val = scalar_value2_bypassed[15:0];
			`MASK_SRC_SCALAR2_INV:	mask_val = ~scalar_value2_bypassed[15:0];
			`MASK_SRC_ALL_ONES:		mask_val = 16'hffff;
			default:				mask_val = {16{1'bx}}; // Don't care
		endcase
	end
	
	wire[511:0] store_value_nxt = ds_store_value_is_vector 
		? vector_value2_bypassed
		: { {15{32'd0}}, scalar_value2_bypassed };
	
	reg branch_taken = 0;
	reg[31:0] branch_target = 0;

	// Determine if the branch was mispredicted and roll this back if so
	assign ex_rollback_request = (ds_branch_predicted ^ branch_taken) 
		&& ds_instruction != `NOP;
	assign ex_rollback_pc = branch_taken ? branch_target : ds_pc;
	
	// Branch control
	always @*
	begin
		if (!is_fmt_c && ds_has_writeback && ds_writeback_reg[4:0] == `REG_PC
			&& !ds_writeback_is_vector)
		begin
			// Arithmetic operation with PC destination, interpret as a branch
			// Can't do this with a memory load in this stage, because the
			// result isn't available yet.
			branch_taken = 1'b1;
			branch_target = single_cycle_result[31:0];
		end
		else if (is_fmt_e)
		begin
			case (branch_type)
				`BRANCH_ALL:			branch_taken = operand1[15:0] == 16'hffff;
				`BRANCH_ZERO:			branch_taken = operand1[31:0] == 32'd0; 
				`BRANCH_NOT_ZERO:		branch_taken = operand1[31:0] != 32'd0; 
				`BRANCH_ALWAYS:			branch_taken = 1'b1; 
				`BRANCH_CALL_OFFSET: 	branch_taken = 1'b1;	 
				`BRANCH_NOT_ALL:		branch_taken = operand1[15:0] != 16'hffff;
				`BRANCH_CALL_REGISTER: 	branch_taken = 1'b1;
				default:				branch_taken = 0;	// Invalid instruction
			endcase

			if (branch_type == `BRANCH_CALL_REGISTER)
				branch_target = operand1[31:0];
			else
				branch_target = ds_pc + branch_offset;
		end
		else
		begin
			branch_taken = 0;
			branch_target = 0;
		end
	end

	// Track multi-cycle instructions
	always @(posedge clk)
	begin
		// Stage 1
		if (is_multi_cycle_latency && !squash_ex0)
		begin
			instruction1			<= #1 ds_instruction;
			strand1					<= #1 ds_strand;
			pc1						<= #1 ds_pc;
			has_writeback1			<= #1 ds_has_writeback;
			writeback_reg1			<= #1 ds_writeback_reg;
			writeback_is_vector1	<= #1 ds_writeback_is_vector;
			mask1					<= #1 mask_val;
		end
		else
		begin
			// Single cycle latency
			instruction1			<= #1 `NOP;
			pc1						<= #1 32'd0;
			has_writeback1			<= #1 1'd0;
			writeback_reg1			<= #1 5'd0;
			writeback_is_vector1	<= #1 1'd0;
			mask1					<= #1 0;
		end
		
		// Stage 2
		if (squash_ex1)
		begin
			instruction2				<= #1 `NOP;
			has_writeback2				<= #1 0;
		end
		else
		begin
			instruction2				<= #1 instruction1;
			has_writeback2				<= #1 has_writeback1;
		end
		
		strand2						<= #1 strand1;
		pc2							<= #1 pc1;
		writeback_reg2				<= #1 writeback_reg1;
		writeback_is_vector2		<= #1 writeback_is_vector1;
		mask2						<= #1 mask1;

		// Stage 3
		if (squash_ex2)
		begin
			instruction3				<= #1 `NOP;
			has_writeback3				<= #1 0;
		end
		else
		begin
			instruction3				<= #1 instruction2;
			has_writeback3				<= #1 has_writeback2;
		end

		strand3						<= #1 strand2;
		pc3							<= #1 pc2;
		writeback_reg3				<= #1 writeback_reg2;
		writeback_is_vector3		<= #1 writeback_is_vector2;
		mask3						<= #1 mask2;
	end

	single_cycle_vector_alu salu(
		.operation_i(ds_alu_op),
		.operand1_i(operand1),
		.operand2_i(operand2),
		.result_o(single_cycle_result));
		
	multi_cycle_vector_alu malu(
		.clk(clk),
		.operation_i(ds_alu_op),
		.operand1_i(operand1),
		.operand2_i(operand2),
		.result_o(multi_cycle_result));

	vector_shuffler shu(
		.value_i(operand1),
		.shuffle_i(operand2),
		.result_o(shuffled));

	assertion #("conflict at end of execute stage") a0(.clk(clk), 
		.test(instruction3 != `NOP && ds_instruction != `NOP && !is_multi_cycle_latency));

	// This is the place where pipelines of different lengths merge. There
	// is a structural hazard here, as two instructions can arrive at the
	// same time.  We don't attempt to resolve that here: the strand scheduler
	// will do that.
	always @*
	begin
		if (instruction3 != `NOP && !squash_ex3)	
		begin
			// Multi-cycle result is available
			instruction_nxt = instruction3;
			strand_nxt = strand3;
			writeback_reg_nxt = writeback_reg3;
			writeback_is_vector_nxt = writeback_is_vector3;
			has_writeback_nxt = has_writeback3;
			pc_nxt = pc3;
			mask_nxt = mask3;
			if (instruction3[28:23] == `OP_FGTR	   // We know this will ony ever be fmt a
				|| instruction3[28:23] == `OP_FLT
				|| instruction3[28:23] == `OP_FGTE
				|| instruction3[28:23] == `OP_FLTE)
			begin
				// This is a comparison.  Coalesce the results.
				result_nxt = { multi_cycle_result[480],
					multi_cycle_result[448],
					multi_cycle_result[416],
					multi_cycle_result[384],
					multi_cycle_result[352],
					multi_cycle_result[320],
					multi_cycle_result[288],
					multi_cycle_result[256],
					multi_cycle_result[224],
					multi_cycle_result[192],
					multi_cycle_result[160],
					multi_cycle_result[128],
					multi_cycle_result[96],
					multi_cycle_result[64],
					multi_cycle_result[32],
					multi_cycle_result[0] };
			end
			else
				result_nxt = multi_cycle_result;
		end
		else if (!is_multi_cycle_latency && !squash_ex0)
		begin
			// Single cycle result
			instruction_nxt = ds_instruction;
			strand_nxt = ds_strand;
			writeback_reg_nxt = ds_writeback_reg;
			writeback_is_vector_nxt = ds_writeback_is_vector;
			has_writeback_nxt = ds_has_writeback;
			pc_nxt = ds_pc;
			mask_nxt = mask_val;
			if (is_call)
				result_nxt = { 480'd0, ds_pc };
			else if (ds_alu_op == `OP_SHUFFLE || ds_alu_op == `OP_GETLANE)
				result_nxt = shuffled;
			else if (ds_alu_op == `OP_EQUAL
				|| ds_alu_op == `OP_NEQUAL
				|| ds_alu_op == `OP_SIGTR
				|| ds_alu_op == `OP_SIGTE
				|| ds_alu_op == `OP_SILT
				|| ds_alu_op == `OP_SILTE
				|| ds_alu_op == `OP_UIGTR
				|| ds_alu_op == `OP_UIGTE
				|| ds_alu_op == `OP_UILT
				|| ds_alu_op == `OP_UILTE)
			begin
				// This is a comparison.  Coalesce the results.
				result_nxt = { single_cycle_result[480],
					single_cycle_result[448],
					single_cycle_result[416],
					single_cycle_result[384],
					single_cycle_result[352],
					single_cycle_result[320],
					single_cycle_result[288],
					single_cycle_result[256],
					single_cycle_result[224],
					single_cycle_result[192],
					single_cycle_result[160],
					single_cycle_result[128],
					single_cycle_result[96],
					single_cycle_result[64],
					single_cycle_result[32],
					single_cycle_result[0] };
			end
			else
				result_nxt = single_cycle_result;
		end
		else
		begin
			instruction_nxt = `NOP;
			strand_nxt = 0;
			writeback_reg_nxt = 0;
			writeback_is_vector_nxt = 0;
			has_writeback_nxt = 0;
			pc_nxt = 0;
			mask_nxt = 0;
			result_nxt = 0;
		end
	end

	always @(posedge clk)
	begin
		ex_strand					<= #1 strand_nxt;
		ex_writeback_reg			<= #1 writeback_reg_nxt;
		ex_writeback_is_vector		<= #1 writeback_is_vector_nxt;
		ex_pc						<= #1 pc_nxt;
		ex_result					<= #1 result_nxt;
		ex_store_value				<= #1 store_value_nxt;
		ex_mask						<= #1 mask_nxt;
		ex_reg_lane_select			<= #1 ds_reg_lane_select;
		ex_strided_offset			<= #1 ds_strided_offset;
		ex_base_addr				<= #1 operand1[31:0];
		ex_instruction				<= #1 instruction_nxt;
		ex_has_writeback			<= #1 has_writeback_nxt;
	end

	//// Performance Counters /////////////////
	reg[63:0] mispredicted_branch_count = 0;

	always @(posedge clk)
	begin
		if (ex_rollback_request)
			mispredicted_branch_count <= #1 mispredicted_branch_count + 1;
	end
	/////////////////////////////////////////////

endmodule
