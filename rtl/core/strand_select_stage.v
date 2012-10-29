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

//
// CPU pipeline strand selection stage.
// Each cycle, this will select a strand to issue to the decode stage.  It 
// detects and schedules around conflict in the pipeline and tracks
// which strands are waiting (for example, on data cache misses)
//

module strand_select_stage(
	input					clk,

	input [3:0]				ma_strand_enable,

	input [31:0]			if_instruction0,
	input					if_instruction_valid0,
	input [31:0]			if_pc0,
	input					if_branch_predicted0,
	input					rb_rollback_strand0,
	input					rb_retry_strand0,
	input					suspend_strand0,
	input					resume_strand0,
	output					ss_instruction_req0,
	input [31:0]			rollback_strided_offset0,
	input [3:0]				rollback_reg_lane0,

	input [31:0]			if_instruction1,
	input					if_instruction_valid1,
	input [31:0]			if_pc1,
	input					if_branch_predicted1,
	input					rb_rollback_strand1,
	input					rb_retry_strand1,
	input					suspend_strand1,
	input					resume_strand1,
	output					ss_instruction_req1,
	input [31:0]			rollback_strided_offset1,
	input [3:0]				rollback_reg_lane1,

	input [31:0]			if_instruction2,
	input					if_instruction_valid2,
	input [31:0]			if_pc2,
	input					if_branch_predicted2,
	input					rb_rollback_strand2,
	input					rb_retry_strand2,
	input					suspend_strand2,
	input					resume_strand2,
	output					ss_instruction_req2,
	input [31:0]			rollback_strided_offset2,
	input [3:0]				rollback_reg_lane2,

	input [31:0]			if_instruction3,
	input					if_instruction_valid3,
	input [31:0]			if_pc3,
	input					if_branch_predicted3,
	input					rb_rollback_strand3,
	input					rb_retry_strand3,
	input					suspend_strand3,
	input					resume_strand3,
	output					ss_instruction_req3,
	input [31:0]			rollback_strided_offset3,
	input [3:0]				rollback_reg_lane3,

	output reg[31:0]		ss_pc = 0,
	output reg[31:0]		ss_instruction = `NOP,
	output reg[3:0]			ss_reg_lane_select = 0,
	output reg[31:0]		ss_strided_offset = 0,
	output reg[1:0]			ss_strand = 0,
	output reg				ss_branch_predicted = 0);

	wire[3:0]				reg_lane_select0;
	wire[31:0]				strided_offset0;
	wire[3:0]				reg_lane_select1;
	wire[31:0]				strided_offset1;
	wire[3:0]				reg_lane_select2;
	wire[31:0]				strided_offset2;
	wire[3:0]				reg_lane_select3;
	wire[31:0]				strided_offset3;
	wire[3:0]				strand_ready;
	wire[3:0]				issue_strand_oh;
	wire[3:0]				execute_hazard;
	reg[63:0]				issue_count = 0;

	execute_hazard_detect ehd(
		.clk(clk),
		.if_instruction0(if_instruction0),
		.if_instruction1(if_instruction1),
		.if_instruction2(if_instruction2),
		.if_instruction3(if_instruction3),
		.issue_oh(issue_strand_oh),
		.execute_hazard(execute_hazard));
	
	strand_fsm strand_fsm0(
		.clk(clk),
		.instruction_i(if_instruction0),
		.instruction_valid_i(if_instruction_valid0),
		.grant_i(issue_strand_oh[0]),
		.issue_request_o(strand_ready[0]),
		.flush_i(rb_rollback_strand0),
		.retry_i(rb_retry_strand0),
		.next_instruction_o(ss_instruction_req0),
		.suspend_strand_i(suspend_strand0),
		.resume_strand_i(resume_strand0),
		.rollback_strided_offset_i(rollback_strided_offset0),
		.rollback_reg_lane_i(rollback_reg_lane0),
		.reg_lane_select_o(reg_lane_select0),
		.strided_offset_o(strided_offset0));

	strand_fsm strand_fsm1(
		.clk(clk),
		.instruction_i(if_instruction1),
		.instruction_valid_i(if_instruction_valid1),
		.grant_i(issue_strand_oh[1]),
		.issue_request_o(strand_ready[1]),
		.flush_i(rb_rollback_strand1),
		.retry_i(rb_retry_strand1),
		.next_instruction_o(ss_instruction_req1),
		.suspend_strand_i(suspend_strand1),
		.resume_strand_i(resume_strand1),
		.rollback_strided_offset_i(rollback_strided_offset1),
		.rollback_reg_lane_i(rollback_reg_lane1),
		.reg_lane_select_o(reg_lane_select1),
		.strided_offset_o(strided_offset1));

	strand_fsm strand_fsm2(
		.clk(clk),
		.instruction_i(if_instruction2),
		.instruction_valid_i(if_instruction_valid2),
		.grant_i(issue_strand_oh[2]),
		.issue_request_o(strand_ready[2]),
		.flush_i(rb_rollback_strand2),
		.retry_i(rb_retry_strand2),
		.next_instruction_o(ss_instruction_req2),
		.suspend_strand_i(suspend_strand2),
		.resume_strand_i(resume_strand2),
		.rollback_strided_offset_i(rollback_strided_offset2),
		.rollback_reg_lane_i(rollback_reg_lane2),
		.reg_lane_select_o(reg_lane_select2),
		.strided_offset_o(strided_offset2));

	strand_fsm strand_fsm3(
		.clk(clk),
		.instruction_i(if_instruction3),
		.instruction_valid_i(if_instruction_valid3),
		.grant_i(issue_strand_oh[3]),
		.issue_request_o(strand_ready[3]),
		.flush_i(rb_rollback_strand3),
		.retry_i(rb_retry_strand3),
		.next_instruction_o(ss_instruction_req3),
		.suspend_strand_i(suspend_strand3),
		.resume_strand_i(resume_strand3),
		.rollback_strided_offset_i(rollback_strided_offset3),
		.rollback_reg_lane_i(rollback_reg_lane3),
		.reg_lane_select_o(reg_lane_select3),
		.strided_offset_o(strided_offset3));

	arbiter #(4) issue_arbiter(
		.clk(clk),
		.request(strand_ready & ma_strand_enable & ~execute_hazard),
		.update_lru(1'b1),
		.grant_oh(issue_strand_oh));

	wire[1:0] issue_strand_idx = { issue_strand_oh[3] || issue_strand_oh[2],
		issue_strand_oh[3] || issue_strand_oh[1] };

	// Output mux
	always @(posedge clk)
	begin
		if (|issue_strand_oh)
		begin
			case (issue_strand_idx)
				0:
				begin
					ss_pc				<= #1 if_pc0;
					ss_instruction		<= #1 if_instruction0;
					ss_branch_predicted <= #1 if_branch_predicted0;
					ss_reg_lane_select	<= #1 reg_lane_select0;
					ss_strided_offset	<= #1 strided_offset0;
				end
				
				1:
				begin
					ss_pc				<= #1 if_pc1;
					ss_instruction		<= #1 if_instruction1;
					ss_branch_predicted <= #1 if_branch_predicted1;
					ss_reg_lane_select	<= #1 reg_lane_select1;
					ss_strided_offset	<= #1 strided_offset1;
				end
				
				2:
				begin
					ss_pc				<= #1 if_pc2;
					ss_instruction		<= #1 if_instruction2;
					ss_branch_predicted <= #1 if_branch_predicted2;
					ss_reg_lane_select	<= #1 reg_lane_select2;
					ss_strided_offset	<= #1 strided_offset2;
				end
				
				3:
				begin
					ss_pc				<= #1 if_pc3;
					ss_instruction		<= #1 if_instruction3;
					ss_branch_predicted <= #1 if_branch_predicted3;
					ss_reg_lane_select	<= #1 reg_lane_select3;
					ss_strided_offset	<= #1 strided_offset3;
				end
			endcase
			
			issue_count <= #1 issue_count + 1;
			ss_strand <= #1 issue_strand_idx;
		end
		else
		begin
			// No strand is ready, issue NOP
			ss_pc 				<= #1 0;
			ss_instruction 		<= #1 `NOP;
			ss_branch_predicted <= #1 0;
		end
	end
endmodule
