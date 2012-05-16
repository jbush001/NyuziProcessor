//
// CPU pipeline strand selection stage.
// Each cycle, this will select a strand to issue to the decode stage.  It 
// detects and schedules around conflict in the pipeline and tracks
// which strands are waiting (for example, on data cache misses)
//

`include "instruction_format.h"

module strand_select_stage(
	input					clk,

	input [3:0]				ma_strand_enable,

	input [31:0]			if_instruction0,
	input					if_instruction_valid0,
	input [31:0]			if_pc0,
	input					rb_rollback_strand0,
	input					suspend_strand0,
	input					resume_strand0,
	output					ss_instruction_req0,
	input [31:0]			rollback_strided_offset0,
	input [3:0]				rollback_reg_lane0,

	input [31:0]			if_instruction1,
	input					if_instruction_valid1,
	input [31:0]			if_pc1,
	input					rb_rollback_strand1,
	input					suspend_strand1,
	input					resume_strand1,
	output					ss_instruction_req1,
	input [31:0]			rollback_strided_offset1,
	input [3:0]				rollback_reg_lane1,

	input [31:0]			if_instruction2,
	input					if_instruction_valid2,
	input [31:0]			if_pc2,
	input					rb_rollback_strand2,
	input					suspend_strand2,
	input					resume_strand2,
	output					ss_instruction_req2,
	input [31:0]			rollback_strided_offset2,
	input [3:0]				rollback_reg_lane2,

	input [31:0]			if_instruction3,
	input					if_instruction_valid3,
	input [31:0]			if_pc3,
	input					rb_rollback_strand3,
	input					suspend_strand3,
	input					resume_strand3,
	output					ss_instruction_req3,
	input [31:0]			rollback_strided_offset3,
	input [3:0]				rollback_reg_lane3,

	output reg[31:0]		ss_pc = 0,
	output reg[31:0]		ss_instruction = 0,
	output reg[3:0]			ss_reg_lane_select = 0,
	output reg[31:0]		ss_strided_offset = 0,
	output reg[1:0]			ss_strand = 0);

	wire[31:0]				pc0;
	wire[31:0]				instruction0;
	wire[3:0]				reg_lane_select0;
	wire[31:0]				strided_offset0;
	wire[31:0]				pc1;
	wire[31:0]				instruction1;
	wire[3:0]				reg_lane_select1;
	wire[31:0]				strided_offset1;
	wire[31:0]				pc2;
	wire[31:0]				instruction2;
	wire[3:0]				reg_lane_select2;
	wire[31:0]				strided_offset2;
	wire[31:0]				pc3;
	wire[31:0]				instruction3;
	wire[3:0]				reg_lane_select3;
	wire[31:0]				strided_offset3;
	wire					strand0_ready;
	wire					strand1_ready;
	wire					strand2_ready;
	wire					strand3_ready;
	wire					issue_strand0;
	wire					issue_strand1;
	wire					issue_strand2;
	wire					issue_strand3;
	wire					execute_hazard0;
	wire					execute_hazard1;
	wire					execute_hazard2;
	wire					execute_hazard3;
	reg[63:0]				idle_cycle_count = 0;

	execute_hazard_detect ehd(
		.clk(clk),
		.if_instruction0(if_instruction0),
		.if_instruction1(if_instruction1),
		.if_instruction2(if_instruction2),
		.if_instruction3(if_instruction3),
		.issue0_i(issue_strand0),
		.issue1_i(issue_strand1),
		.issue2_i(issue_strand2),
		.issue3_i(issue_strand3),
		.execute_hazard0_o(execute_hazard0),
		.execute_hazard1_o(execute_hazard1),
		.execute_hazard2_o(execute_hazard2),
		.execute_hazard3_o(execute_hazard3));
	
	strand_fsm strand_fsm0(
		.clk(clk),
		.instruction_i(if_instruction0),
		.instruction_valid_i(if_instruction_valid0),
		.grant_i(issue_strand0),
		.issue_request_o(strand0_ready),
		.pc_i(if_pc0),
		.flush_i(rb_rollback_strand0),
		.next_instruction_o(ss_instruction_req0),
		.suspend_strand_i(suspend_strand0),
		.resume_strand_i(resume_strand0),
		.rollback_strided_offset_i(rollback_strided_offset0),
		.rollback_reg_lane_i(rollback_reg_lane0),
		.pc_o(pc0),
		.instruction_o(instruction0),
		.reg_lane_select_o(reg_lane_select0),
		.strided_offset_o(strided_offset0));

	strand_fsm strand_fsm1(
		.clk(clk),
		.instruction_i(if_instruction1),
		.instruction_valid_i(if_instruction_valid1),
		.grant_i(issue_strand1),
		.issue_request_o(strand1_ready),
		.pc_i(if_pc1),
		.flush_i(rb_rollback_strand1),
		.next_instruction_o(ss_instruction_req1),
		.suspend_strand_i(suspend_strand1),
		.resume_strand_i(resume_strand1),
		.rollback_strided_offset_i(rollback_strided_offset1),
		.rollback_reg_lane_i(rollback_reg_lane1),
		.pc_o(pc1),
		.instruction_o(instruction1),
		.reg_lane_select_o(reg_lane_select1),
		.strided_offset_o(strided_offset1));

	strand_fsm strand_fsm2(
		.clk(clk),
		.instruction_i(if_instruction2),
		.instruction_valid_i(if_instruction_valid2),
		.grant_i(issue_strand2),
		.issue_request_o(strand2_ready),
		.pc_i(if_pc2),
		.flush_i(rb_rollback_strand2),
		.next_instruction_o(ss_instruction_req2),
		.suspend_strand_i(suspend_strand2),
		.resume_strand_i(resume_strand2),
		.rollback_strided_offset_i(rollback_strided_offset2),
		.rollback_reg_lane_i(rollback_reg_lane2),
		.pc_o(pc2),
		.instruction_o(instruction2),
		.reg_lane_select_o(reg_lane_select2),
		.strided_offset_o(strided_offset2));

	strand_fsm strand_fsm3(
		.clk(clk),
		.instruction_i(if_instruction3),
		.instruction_valid_i(if_instruction_valid3),
		.grant_i(issue_strand3),
		.issue_request_o(strand3_ready),
		.pc_i(if_pc3),
		.flush_i(rb_rollback_strand3),
		.next_instruction_o(ss_instruction_req3),
		.suspend_strand_i(suspend_strand3),
		.resume_strand_i(resume_strand3),
		.rollback_strided_offset_i(rollback_strided_offset3),
		.rollback_reg_lane_i(rollback_reg_lane3),
		.pc_o(pc3),
		.instruction_o(instruction3),
		.reg_lane_select_o(reg_lane_select3),
		.strided_offset_o(strided_offset3));

	arbiter4 issue_arbiter(
		.clk(clk),
		.req0_i(strand0_ready && ma_strand_enable[0] && !execute_hazard0),
		.req1_i(strand1_ready && ma_strand_enable[1] && !execute_hazard1),
		.req2_i(strand2_ready && ma_strand_enable[2] && !execute_hazard2),
		.req3_i(strand3_ready && ma_strand_enable[3] && !execute_hazard3),
		.update_lru_i(1'b1),
		.grant0_o(issue_strand0),
		.grant1_o(issue_strand1),
		.grant2_o(issue_strand2),
		.grant3_o(issue_strand3));

	// Output mux
	always @(posedge clk)
	begin
		if (issue_strand0)
		begin
			ss_pc				<= #1 pc0;
			ss_instruction		<= #1 instruction0;
			ss_reg_lane_select	<= #1 reg_lane_select0;
			ss_strided_offset	<= #1 strided_offset0;
			ss_strand			<= #1 0;
		end
		else if (issue_strand1)
		begin
			ss_pc				<= #1 pc1;
			ss_instruction		<= #1 instruction1;
			ss_reg_lane_select	<= #1 reg_lane_select1;
			ss_strided_offset	<= #1 strided_offset1;
			ss_strand			<= #1 1;
		end
		else if (issue_strand2)
		begin
			ss_pc				<= #1 pc2;
			ss_instruction		<= #1 instruction2;
			ss_reg_lane_select	<= #1 reg_lane_select2;
			ss_strided_offset	<= #1 strided_offset2;
			ss_strand			<= #1 2;
		end
		else if (issue_strand3)
		begin
			ss_pc				<= #1 pc3;
			ss_instruction		<= #1 instruction3;
			ss_reg_lane_select	<= #1 reg_lane_select3;
			ss_strided_offset	<= #1 strided_offset3;
			ss_strand			<= #1 3;
		end
		else
		begin
			// No strand is ready, issue NOP
			ss_pc 				<= #1 0;
			ss_instruction 		<= #1 `NOP;
			ss_reg_lane_select 	<= #1 0;
			ss_strided_offset 	<= #1 0;
			ss_strand			<= #1 0;
			idle_cycle_count	<= #1 idle_cycle_count + 1;	// Performance counter
		end
	end
endmodule
