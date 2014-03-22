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
// Instruction pipeline execute stage
// - Performs arithmetic operations
// - Detects branch mispredictions
// - Issues address to data cache for tag check
// - Handles bypassing of register results that have not been committed
//	   to register file yet.
//

module execute_stage(
	input                                   clk,
	input                                   reset,
	
	// From decode stage
	input [31:0]                            ds_instruction,
	input                                   ds_branch_predicted,
	input [`STRAND_INDEX_WIDTH - 1:0]       ds_strand,
	input [31:0]                            ds_pc,
	input [31:0]                            ds_immediate_value,
	input mask_src_t                        ds_mask_src,
	input                                   ds_op1_is_vector,
	input op2_src_t                         ds_op2_src,
	input                                   ds_store_value_is_vector,
	input [`REG_IDX_WIDTH - 1:0]            ds_writeback_reg,
	input                                   ds_enable_scalar_writeback,	
	input                                   ds_enable_vector_writeback,
	input arith_opcode_t                    ds_alu_op,
	input [3:0]                             ds_reg_lane_select,
	input [31:0]                            ds_strided_offset,
	input                                   ds_long_latency,
	input [`REG_IDX_WIDTH - 1:0]            ds_scalar_sel1_l,
	input [`REG_IDX_WIDTH - 1:0]            ds_scalar_sel2_l,
	input [`REG_IDX_WIDTH - 1:0]            ds_vector_sel1_l,
	input [`REG_IDX_WIDTH - 1:0]            ds_vector_sel2_l,

	// From register files
	input [31:0]                            scalar_value1,
	input [31:0]                            scalar_value2,
	input [`VECTOR_BITS - 1:0]              vector_value1,
	input [`VECTOR_BITS - 1:0]              vector_value2,
	
	// To memory access stage
	output logic[31:0]                      ex_instruction,
	output logic[`STRAND_INDEX_WIDTH - 1:0] ex_strand,
	output logic[31:0]                      ex_pc,
	output logic[`VECTOR_BITS - 1:0]        ex_store_value,
	output logic[`REG_IDX_WIDTH - 1:0]      ex_writeback_reg,
	output logic                            ex_enable_scalar_writeback,
	output logic                            ex_enable_vector_writeback,
	output logic[`VECTOR_LANES - 1:0]       ex_mask,
	output logic[`VECTOR_BITS - 1:0]        ex_result,
	output logic[3:0]                       ex_reg_lane_select,
	output logic [31:0]                     ex_strided_offset,
	output logic [31:0]                     ex_base_addr,

	// To/from rollback controller
	output                                  ex_rollback_request,
	output [31:0]                           ex_rollback_pc,
	input                                   rb_squash_ex0,
	input                                   rb_squash_ex1,
	input                                   rb_squash_ex2,
	input                                   rb_squash_ex3,
	output[`STRAND_INDEX_WIDTH - 1:0]       ex_strand1,
	output[`STRAND_INDEX_WIDTH - 1:0]       ex_strand2,
	output[`STRAND_INDEX_WIDTH - 1:0]       ex_strand3,

	// Register bypass signals from reset of pipeline
	input [`REG_IDX_WIDTH - 1:0]            ma_writeback_reg,		// mem access stage
	input                                   ma_enable_scalar_writeback,
	input                                   ma_enable_vector_writeback,
	input [`VECTOR_BITS - 1:0]              ma_result,
	input [`VECTOR_LANES - 1:0]             ma_mask,
	input [`REG_IDX_WIDTH - 1:0]            wb_writeback_reg,		// writeback stage
	input                                   wb_enable_scalar_writeback,
	input                                   wb_enable_vector_writeback,
	input [`VECTOR_BITS - 1:0]              wb_writeback_value,
	input [`VECTOR_LANES - 1:0]             wb_writeback_mask,
	input [`REG_IDX_WIDTH - 1:0]            rf_writeback_reg,		// post writeback
	input                                   rf_enable_scalar_writeback,
	input                                   rf_enable_vector_writeback,
	input [`VECTOR_BITS - 1:0]              rf_writeback_value,
	input [`VECTOR_LANES - 1:0]             rf_writeback_mask,
	
	// Performance counter events
	output                                  pc_event_mispredicted_branch,
	output                                  pc_event_uncond_branch,
	output                                  pc_event_cond_branch_taken,
	output                                  pc_event_cond_branch_not_taken);
	
	logic[`VECTOR_BITS - 1:0] operand2;
	logic[`VECTOR_BITS - 1:0] single_stage_result;
	logic[`VECTOR_BITS - 1:0] multi_stage_result;
	logic[`VECTOR_LANES - 1:0] mask_val;
	logic[`VECTOR_BITS - 1:0] vector_value1_bypassed;
	logic[`VECTOR_BITS - 1:0] vector_value2_bypassed;
	logic[31:0] scalar_value1_bypassed;
	logic[31:0] scalar_value2_bypassed;
	logic[31:0] instruction_nxt;
	logic[`STRAND_INDEX_WIDTH - 1:0] strand_nxt;
	logic[`REG_IDX_WIDTH - 1:0] writeback_reg_nxt;
	logic enable_scalar_writeback_nxt;
	logic enable_vector_writeback_nxt;
	logic[31:0] pc_nxt;
	logic[`VECTOR_BITS - 1:0] result_nxt;
	logic[`VECTOR_LANES - 1:0] mask_nxt;

	// Track instructions with multi-cycle latency.
	logic[31:0] instruction1;
	logic[`STRAND_INDEX_WIDTH - 1:0] strand1;
	logic[31:0] pc1;
	logic enable_scalar_writeback1;
	logic enable_vector_writeback1;
	logic[`REG_IDX_WIDTH - 1:0] writeback_reg1;
	logic[`VECTOR_LANES - 1:0] mask1;
	logic[31:0] instruction2;
	logic[`STRAND_INDEX_WIDTH - 1:0] strand2;
	logic[31:0] pc2;
	logic enable_scalar_writeback2;
	logic enable_vector_writeback2;
	logic[`REG_IDX_WIDTH - 1:0] writeback_reg2;
	logic[`VECTOR_LANES - 1:0] mask2;
	logic[31:0] instruction3;
	logic[`STRAND_INDEX_WIDTH - 1:0] strand3;
	logic[31:0] pc3;
	logic enable_scalar_writeback3;
	logic enable_vector_writeback3;
	logic[`REG_IDX_WIDTH - 1:0] writeback_reg3;
	logic[`VECTOR_LANES - 1:0] mask3;
	logic[`VECTOR_BITS - 1:0] shuffled;
	
	assign ex_strand1 = strand1;
	assign ex_strand2 = strand2;
	assign ex_strand3 = strand3;
	
	wire is_fmt_c = ds_instruction[31:30] == 2'b10;	
	wire is_fmt_e = ds_instruction[31:28] == 4'b1111;
	branch_type_t branch_type;
	assign branch_type = branch_type_t'(ds_instruction[27:25]);
	wire is_call = is_fmt_e && (branch_type == BRANCH_CALL_OFFSET
		|| branch_type == BRANCH_CALL_REGISTER);
	wire[31:0] branch_offset = { {12{ds_instruction[24]}}, ds_instruction[24:5] };

	// scalar_value1_bypassed
	always_comb
	begin
		if (ds_scalar_sel1_l[4:0] == `REG_PC)
			scalar_value1_bypassed = ds_pc;
		else if (ds_scalar_sel1_l == ex_writeback_reg && ex_enable_scalar_writeback)
			scalar_value1_bypassed = ex_result[31:0];
		else if (ds_scalar_sel1_l == ma_writeback_reg && ma_enable_scalar_writeback)
			scalar_value1_bypassed = ma_result[31:0];
		else if (ds_scalar_sel1_l == wb_writeback_reg && wb_enable_scalar_writeback)
			scalar_value1_bypassed = wb_writeback_value[31:0];
		else if (ds_scalar_sel1_l == rf_writeback_reg && rf_enable_scalar_writeback)
			scalar_value1_bypassed = rf_writeback_value[31:0];
		else 
			scalar_value1_bypassed = scalar_value1;	
	end

	// scalar_value2_bypassed
	always_comb
	begin
		if (ds_scalar_sel2_l[4:0] == `REG_PC)
			scalar_value2_bypassed = ds_pc;
		else if (ds_scalar_sel2_l == ex_writeback_reg && ex_enable_scalar_writeback)
			scalar_value2_bypassed = ex_result[31:0];
		else if (ds_scalar_sel2_l == ma_writeback_reg && ma_enable_scalar_writeback)
			scalar_value2_bypassed = ma_result[31:0];
		else if (ds_scalar_sel2_l == wb_writeback_reg && wb_enable_scalar_writeback)
			scalar_value2_bypassed = wb_writeback_value[31:0];
		else if (ds_scalar_sel2_l == rf_writeback_reg && rf_enable_scalar_writeback)
			scalar_value2_bypassed = rf_writeback_value[31:0];
		else 
			scalar_value2_bypassed = scalar_value2;	
	end

	// vector_value1_bypassed
	vector_bypass_unit vbu1(
		.register_sel_i(ds_vector_sel1_l), 
		.data_i(vector_value1),	
		.value_o(vector_value1_bypassed),
		.bypass1_register_i(ex_writeback_reg),	
		.bypass1_write_i(ex_enable_vector_writeback),
		.bypass1_value_i(ex_result),
		.bypass1_mask_i(ex_mask),
		.bypass2_register_i(ma_writeback_reg),	
		.bypass2_write_i(ma_enable_vector_writeback),
		.bypass2_value_i(ma_result),
		.bypass2_mask_i(ma_mask),
		.bypass3_register_i(wb_writeback_reg),	
		.bypass3_write_i(wb_enable_vector_writeback),
		.bypass3_value_i(wb_writeback_value),
		.bypass3_mask_i(wb_writeback_mask),
		.bypass4_register_i(rf_writeback_reg),	
		.bypass4_write_i(rf_enable_vector_writeback),
		.bypass4_value_i(rf_writeback_value),
		.bypass4_mask_i(rf_writeback_mask));

	// vector_value2_bypassed
	vector_bypass_unit vbu2(
		.register_sel_i(ds_vector_sel2_l), 
		.data_i(vector_value2),	
		.value_o(vector_value2_bypassed),
		.bypass1_register_i(ex_writeback_reg),	
		.bypass1_write_i(ex_enable_vector_writeback),
		.bypass1_value_i(ex_result),
		.bypass1_mask_i(ex_mask),
		.bypass2_register_i(ma_writeback_reg),	
		.bypass2_write_i(ma_enable_vector_writeback),
		.bypass2_value_i(ma_result),
		.bypass2_mask_i(ma_mask),
		.bypass3_register_i(wb_writeback_reg),	
		.bypass3_write_i(wb_enable_vector_writeback),
		.bypass3_value_i(wb_writeback_value),
		.bypass3_mask_i(wb_writeback_mask),
		.bypass4_register_i(rf_writeback_reg),	
		.bypass4_write_i(rf_enable_vector_writeback),
		.bypass4_value_i(rf_writeback_value),
		.bypass4_mask_i(rf_writeback_mask));

	wire[`VECTOR_BITS - 1:0] operand1 = ds_op1_is_vector ? vector_value1_bypassed
		: {`VECTOR_LANES{scalar_value1_bypassed}};

	// operand2
	always_comb
	begin
		unique case (ds_op2_src)
			OP2_SRC_SCALAR2:	operand2 = {`VECTOR_LANES{scalar_value2_bypassed}};
			OP2_SRC_VECTOR2:	operand2 = vector_value2_bypassed;
			OP2_SRC_IMMEDIATE: operand2 = {`VECTOR_LANES{ds_immediate_value}};
			default:			operand2 = {512{1'bx}}; // Don't care
		endcase
	end
	
	// mask
	always_comb
	begin
		unique case (ds_mask_src)
			MASK_SRC_SCALAR1:		mask_val = scalar_value1_bypassed[`VECTOR_LANES - 1:0];
			MASK_SRC_SCALAR1_INV:	mask_val = ~scalar_value1_bypassed[`VECTOR_LANES - 1:0];
			MASK_SRC_SCALAR2:		mask_val = scalar_value2_bypassed[`VECTOR_LANES - 1:0];
			MASK_SRC_SCALAR2_INV:	mask_val = ~scalar_value2_bypassed[`VECTOR_LANES - 1:0];
			MASK_SRC_ALL_ONES:		mask_val = {`VECTOR_LANES{1'b1}};
			default:				mask_val = {`VECTOR_LANES{1'bx}}; // Don't care
		endcase
	end
	
	wire[`VECTOR_BITS - 1:0] store_value_nxt = ds_store_value_is_vector 
		? vector_value2_bypassed
		: { {15{32'd0}}, scalar_value2_bypassed };
	
	logic branch_taken;
	logic[31:0] branch_target;

	// Determine if the branch was mispredicted and roll this back if so
	assign ex_rollback_request = (ds_branch_predicted ^ branch_taken) 
		&& ds_instruction != `NOP;
	assign ex_rollback_pc = branch_taken ? branch_target : ds_pc;
	
	// Detect if a branch was actually taken
	always_comb
	begin
		if (!is_fmt_c && ds_enable_scalar_writeback && ds_writeback_reg[4:0] == `REG_PC)
		begin
			// Arithmetic operation with PC destination, interpret as a branch
			// Can't do this with a memory load in this stage, because the
			// result isn't available yet.
			branch_taken = 1'b1;
			branch_target = single_stage_result[31:0];
		end
		else if (is_fmt_e)
		begin
			unique case (branch_type)
				BRANCH_ALL:				branch_taken = operand1[`VECTOR_LANES - 1:0] == {`VECTOR_LANES{1'b1}};
				BRANCH_ZERO:			branch_taken = operand1[31:0] == 32'd0; 
				BRANCH_NOT_ZERO:		branch_taken = operand1[31:0] != 32'd0; 
				BRANCH_ALWAYS:			branch_taken = 1'b1; 
				BRANCH_CALL_OFFSET: 	branch_taken = 1'b1;	 
				BRANCH_NOT_ALL:			branch_taken = operand1[`VECTOR_LANES - 1:0] != {`VECTOR_LANES{1'b1}};
				BRANCH_CALL_REGISTER: 	branch_taken = 1'b1;
				default:				branch_taken = 0;	// Invalid instruction
			endcase

			if (branch_type == BRANCH_CALL_REGISTER)
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

	wire is_conditional_branch = is_fmt_e && (branch_type == BRANCH_ZERO
		|| branch_type == BRANCH_ALL || branch_type == BRANCH_NOT_ZERO
		|| branch_type == BRANCH_NOT_ALL); 
	assign pc_event_mispredicted_branch = ex_rollback_request;
	assign pc_event_uncond_branch = !is_conditional_branch && branch_taken && !rb_squash_ex0; 
	assign pc_event_cond_branch_taken = is_conditional_branch && branch_taken && !rb_squash_ex0;
	assign pc_event_cond_branch_not_taken = is_conditional_branch && !branch_taken && !rb_squash_ex0;

	single_stage_alu salu[`VECTOR_LANES - 1:0] (
				     .single_stage_result(single_stage_result),
				     .operand1		(operand1),
				     .operand2		(operand2),
					/*AUTOINST*/
						    // Inputs
						    .ds_alu_op		(ds_alu_op));
		
	multi_stage_alu malu[`VECTOR_LANES - 1:0] (
				    .multi_stage_result	(multi_stage_result),
				    .operand1		(operand1),
				    .operand2		(operand2),
					/*AUTOINST*/
						   // Inputs
						   .clk			(clk),
						   .reset		(reset),
						   .ds_alu_op		(ds_alu_op));

	logic[(`VECTOR_LANES * $clog2(`VECTOR_LANES)) - 1:0] shuffle_select;

	genvar shuffle_lane;
	generate
		// The low 4 bits of each element of the second vector param is an index
		// that selects an element from the first vector param.
		for (shuffle_lane = 0; shuffle_lane < `VECTOR_LANES; shuffle_lane++)
		begin : lane_select
			assign shuffle_select[shuffle_lane * 4+:4] = operand2[shuffle_lane * 32+:
				4];
		end
	endgenerate

	multiplexer #(.WIDTH(32), .NUM_INPUTS(`VECTOR_LANES), .ASCENDING_INDEX(1)) 
		vector_shuffler[`VECTOR_LANES - 1:0](
		.in(operand1),
		.select(shuffle_select),
		.out(shuffled));

	arith_opcode_t instruction3_opcode;
	assign instruction3_opcode = arith_opcode_t'({ 1'b0, instruction3[25:20] });

	logic[`VECTOR_LANES - 1:0] multi_cycle_compare_result;
	logic[`VECTOR_LANES - 1:0] single_cycle_compare_result;
	
	// Pack vector compare results for each lane into low bits.
	genvar compare_lane;
	generate
		for (compare_lane = 0; compare_lane < `VECTOR_LANES; compare_lane++)
		begin : pack_compare
			assign multi_cycle_compare_result[compare_lane] = multi_stage_result[
				compare_lane * 32];
			assign single_cycle_compare_result[compare_lane] = single_stage_result[
				compare_lane * 32];
		end
	endgenerate

	// This is the place where pipelines of different lengths merge. There
	// is a structural hazard here, as two instructions can arrive at the
	// same time.  We don't attempt to resolve that here: the strand scheduler
	// will do that.
	always_comb
	begin
		if (instruction3 != `NOP && !rb_squash_ex3)	
		begin
			// Multi-cycle result is available
			instruction_nxt = instruction3;
			strand_nxt = strand3;
			writeback_reg_nxt = writeback_reg3;
			enable_scalar_writeback_nxt = enable_scalar_writeback3;
			enable_vector_writeback_nxt = enable_vector_writeback3;
			pc_nxt = pc3;
			mask_nxt = mask3;
			if (instruction3_opcode == OP_FGTR	   // We know this will ony ever be fmt a
				|| instruction3_opcode == OP_FLT
				|| instruction3_opcode == OP_FGTE
				|| instruction3_opcode == OP_FLTE)
			begin
				// This is a comparison.  
				result_nxt = { 496'd0, multi_cycle_compare_result };
			end
			else
				result_nxt = multi_stage_result;
		end
		else if (!ds_long_latency && !rb_squash_ex0)
		begin
			// Single cycle result
			instruction_nxt = ds_instruction;
			strand_nxt = ds_strand;
			writeback_reg_nxt = ds_writeback_reg;
			enable_scalar_writeback_nxt = ds_enable_scalar_writeback;
			enable_vector_writeback_nxt = ds_enable_vector_writeback;
			pc_nxt = ds_pc;
			mask_nxt = mask_val;
			if (is_call)
				result_nxt = { 480'd0, ds_pc };
			else if (ds_alu_op == OP_SHUFFLE || ds_alu_op == OP_GETLANE)
				result_nxt = shuffled;
			else if (ds_alu_op == OP_EQUAL
				|| ds_alu_op == OP_NEQUAL
				|| ds_alu_op == OP_SIGTR
				|| ds_alu_op == OP_SIGTE
				|| ds_alu_op == OP_SILT
				|| ds_alu_op == OP_SILTE
				|| ds_alu_op == OP_UIGTR
				|| ds_alu_op == OP_UIGTE
				|| ds_alu_op == OP_UILT
				|| ds_alu_op == OP_UILTE)
			begin
				// This is a comparison. 
				result_nxt = { 496'd0, single_cycle_compare_result };
			end
			else
				result_nxt = single_stage_result;
		end
		else
		begin
			instruction_nxt = `NOP;
			strand_nxt = 0;
			writeback_reg_nxt = 0;
			enable_scalar_writeback_nxt = 0;
			enable_vector_writeback_nxt = 0;
			pc_nxt = 0;
			mask_nxt = 0;
			result_nxt = 0;
		end
	end

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			enable_scalar_writeback1 <= 1'h0;
			enable_scalar_writeback2 <= 1'h0;
			enable_scalar_writeback3 <= 1'h0;
			enable_vector_writeback1 <= 1'h0;
			enable_vector_writeback2 <= 1'h0;
			enable_vector_writeback3 <= 1'h0;
			ex_base_addr <= 32'h0;
			ex_enable_scalar_writeback <= 1'h0;
			ex_enable_vector_writeback <= 1'h0;
			ex_instruction <= 32'h0;
			ex_mask <= {(1+(`VECTOR_LANES-1)){1'b0}};
			ex_pc <= 32'h0;
			ex_reg_lane_select <= 4'h0;
			ex_result <= {(1+(`VECTOR_BITS-1)){1'b0}};
			ex_store_value <= {(1+(`VECTOR_BITS-1)){1'b0}};
			ex_strand <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			ex_strided_offset <= 32'h0;
			ex_writeback_reg <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			instruction1 <= 32'h0;
			instruction2 <= 32'h0;
			instruction3 <= 32'h0;
			mask1 <= {(1+(`VECTOR_LANES-1)){1'b0}};
			mask2 <= {(1+(`VECTOR_LANES-1)){1'b0}};
			mask3 <= {(1+(`VECTOR_LANES-1)){1'b0}};
			pc1 <= 32'h0;
			pc2 <= 32'h0;
			pc3 <= 32'h0;
			strand1 <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			strand2 <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			strand3 <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			writeback_reg1 <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			writeback_reg2 <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			writeback_reg3 <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			// End of automatics
		end
		else
		begin
			// Check for writeback conflict at end of execute stage
			assert(!(instruction3 != `NOP && ds_instruction != `NOP && !ds_long_latency));

			ex_strand					<= strand_nxt;
			ex_writeback_reg			<= writeback_reg_nxt;
			ex_enable_vector_writeback <= enable_vector_writeback_nxt;
			ex_enable_scalar_writeback <= enable_scalar_writeback_nxt;
			ex_pc						<= pc_nxt;
			ex_result					<= result_nxt;
			ex_store_value				<= store_value_nxt;
			ex_mask						<= mask_nxt;
			ex_reg_lane_select			<= ds_reg_lane_select;
			ex_strided_offset			<= ds_strided_offset;
			ex_base_addr				<= operand1[31:0];
			ex_instruction				<= instruction_nxt;

			// Track multi-cycle instructions ////
			// Stage 1
			if (ds_long_latency && !rb_squash_ex0)
			begin
				instruction1			<= ds_instruction;
				strand1					<= ds_strand;
				pc1						<= ds_pc;
				writeback_reg1			<= ds_writeback_reg;
				enable_vector_writeback1 <= ds_enable_vector_writeback;
				enable_scalar_writeback1 <= ds_enable_scalar_writeback;
				mask1					<= mask_val;
			end
			else
			begin
				// Single cycle latency
				instruction1			<= `NOP;
				pc1						<= 32'd0;
				writeback_reg1			<= 5'd0;
				enable_vector_writeback1 <= 0;
				enable_scalar_writeback1 <= 0;
				mask1					<= 0;
			end
			
			// Stage 2
			if (rb_squash_ex1)
			begin
				instruction2				<= `NOP;
				enable_vector_writeback2 	<= 0;
				enable_scalar_writeback2 	<= 0;
			end
			else
			begin
				instruction2				<= instruction1;
				enable_vector_writeback2 	<= enable_vector_writeback1;
				enable_scalar_writeback2 	<= enable_scalar_writeback1;
			end
			
			strand2						<= strand1;
			pc2							<= pc1;
			writeback_reg2				<= writeback_reg1;
			mask2						<= mask1;
	
			// Stage 3
			if (rb_squash_ex2)
			begin
				instruction3				<= `NOP;
				enable_vector_writeback3 	<= 0;
				enable_scalar_writeback3 	<= 0;
			end
			else
			begin
				instruction3				<= instruction2;
				enable_vector_writeback3 	<= enable_vector_writeback2;
				enable_scalar_writeback3 	<= enable_scalar_writeback2;
			end
	
			strand3						<= strand2;
			pc3							<= pc2;
			writeback_reg3				<= writeback_reg2;
			mask3						<= mask2;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
