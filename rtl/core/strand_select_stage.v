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
// Instruction pipeline strand selection stage.
// Each cycle, this will select a strand to issue to the decode stage.  It 
// detects and schedules around conflicts in the pipeline and tracks
// which strands are waiting (for example, on data cache misses)
//

module strand_select_stage(
	input									clk,
	input									reset,

	// From control register unit
	input [`STRANDS_PER_CORE - 1:0]			cr_strand_enable,

	// To/from instruction fetch stage
	// All of the strands are concatenated together.
	input [`STRANDS_PER_CORE - 1:0]			if_instruction_valid,
	input [`STRANDS_PER_CORE * 32 - 1:0] 	if_instruction,
	input [`STRANDS_PER_CORE * 32 - 1:0] 	if_pc,
	input [`STRANDS_PER_CORE - 1:0]			if_branch_predicted,
	input [`STRANDS_PER_CORE - 1:0]			if_long_latency,
	output [`STRANDS_PER_CORE - 1:0] 		ss_instruction_req,

	// From rollback controller
	input [`STRANDS_PER_CORE - 1:0] 		rb_rollback_strand,
	input [`STRANDS_PER_CORE - 1:0] 		rb_retry_strand,
	input [`STRANDS_PER_CORE - 1:0] 		suspend_strand,
	input [`STRANDS_PER_CORE - 1:0] 		resume_strand,
	input [`STRANDS_PER_CORE * 32 - 1:0] 	rollback_strided_offset,
	input [`STRANDS_PER_CORE * 4 - 1:0] 	rollback_reg_lane,

	// Outputs to decode stage.
	output reg[31:0]						ss_pc,
	output reg[31:0]						ss_instruction,
	output reg[3:0]							ss_reg_lane_select,
	output reg[31:0]						ss_strided_offset,
	output reg[1:0]							ss_strand,
	output reg								ss_branch_predicted,
	output reg								ss_long_latency,
	
	// Performance counter events
	output [`STRANDS_PER_CORE - 1:0]		pc_event_raw_wait,
	output [`STRANDS_PER_CORE - 1:0]		pc_event_dcache_wait,
	output [`STRANDS_PER_CORE - 1:0]		pc_event_icache_wait,
	output 									pc_event_instruction_issue);

	wire[`STRANDS_PER_CORE * 4 - 1:0] reg_lane_select;
	wire[32 * `STRANDS_PER_CORE - 1:0] strided_offset;
	wire[`STRANDS_PER_CORE - 1:0] strand_ready;
	wire[`STRANDS_PER_CORE - 1:0] issue_strand_oh;

	//
	// At the end of the execute stage, the single and multi-cycle pipelines merge
	// at a mux.  This creates a hazard where an instruction can arrive at the end
	// of both pipelines simultaneously. This logic tracks instructions through the 
	// pipeline and avoids issuing instructions that would conflict.  For each of the 
	// instructions that could be issued, it sets a signal indicating if the 
	// instruction would cause a conflict.
	//
	// Each bit in this shift register corresponds to an instruction in a stage.
	reg[2:0] writeback_allocate_ff;
	wire[`STRANDS_PER_CORE - 1:0] short_latency;

	wire[`STRANDS_PER_CORE - 1:0] execute_hazard = {`STRANDS_PER_CORE{writeback_allocate_ff[2]}} & short_latency;
	wire issue_long_latency = (issue_strand_oh & if_long_latency) != 0;
	wire[2:0] writeback_allocate_nxt = { writeback_allocate_ff[1:0], 
		issue_long_latency };

	// Note: don't use [] in params to make array instantiation work correctly.
	// auto template ensures that doesn't happen.
	/* strand_fsm AUTO_TEMPLATE(
		.\(.*\)(\1),);
	*/
	strand_fsm strand_fsm[`STRANDS_PER_CORE - 1:0] (
		/*AUTOINST*/
							// Outputs
							.ss_instruction_req(ss_instruction_req), // Templated
							.strand_ready	(strand_ready),	 // Templated
							.reg_lane_select(reg_lane_select), // Templated
							.strided_offset	(strided_offset), // Templated
							.pc_event_raw_wait(pc_event_raw_wait), // Templated
							.pc_event_dcache_wait(pc_event_dcache_wait), // Templated
							.pc_event_icache_wait(pc_event_icache_wait), // Templated
							// Inputs
							.clk		(clk),		 // Templated
							.reset		(reset),	 // Templated
							.if_instruction_valid(if_instruction_valid), // Templated
							.if_instruction	(if_instruction), // Templated
							.if_long_latency(if_long_latency), // Templated
							.issue_strand_oh(issue_strand_oh), // Templated
							.rb_rollback_strand(rb_rollback_strand), // Templated
							.suspend_strand	(suspend_strand), // Templated
							.rb_retry_strand(rb_retry_strand), // Templated
							.resume_strand	(resume_strand), // Templated
							.rollback_strided_offset(rollback_strided_offset), // Templated
							.rollback_reg_lane(rollback_reg_lane)); // Templated

	genvar strand_id;

	generate
		for (strand_id = 0; strand_id < `STRANDS_PER_CORE; strand_id = strand_id + 1)
		begin : fsm
			assign short_latency[strand_id] = !if_long_latency[strand_id] 
				&& if_instruction[(strand_id + 1) * 32 - 1:strand_id * 32] != `NOP;
		end
	endgenerate

	arbiter #(.NUM_ENTRIES(`STRANDS_PER_CORE)) issue_arbiter(
		.request(strand_ready & cr_strand_enable & ~execute_hazard),
		.update_lru(1'b1),
		.grant_oh(issue_strand_oh),
		/*AUTOINST*/
								 // Inputs
								 .clk			(clk),
								 .reset			(reset));

	wire[`STRAND_INDEX_WIDTH - 1:0] issue_strand_idx;
	one_hot_to_index #(.NUM_SIGNALS(`STRANDS_PER_CORE)) cvt_cache_request(
		.one_hot(issue_strand_oh),
		.index(issue_strand_idx));

	assign pc_event_instruction_issue = issue_strand_oh != 0;
	
	// Output mux
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			ss_branch_predicted <= 1'h0;
			ss_instruction <= 32'h0;
			ss_long_latency <= 1'h0;
			ss_pc <= 32'h0;
			ss_reg_lane_select <= 4'h0;
			ss_strand <= 2'h0;
			ss_strided_offset <= 32'h0;
			writeback_allocate_ff <= 3'h0;
			// End of automatics
		end
		else
		begin
			writeback_allocate_ff <= writeback_allocate_nxt;

			if (issue_strand_oh != 0)
			begin
				case (issue_strand_idx)
					0:
					begin
						ss_pc				<= if_pc[31:0];
						ss_instruction		<= if_instruction[31:0];
						ss_branch_predicted <= if_branch_predicted[0];
						ss_long_latency 	<= if_long_latency[0];
						ss_reg_lane_select	<= reg_lane_select[3:0];
						ss_strided_offset	<= strided_offset[31:0];
					end
					
					1:
					begin
						ss_pc				<= if_pc[63:32];
						ss_instruction		<= if_instruction[63:32];
						ss_branch_predicted <= if_branch_predicted[1];
						ss_long_latency 	<= if_long_latency[1];
						ss_reg_lane_select	<= reg_lane_select[7:4];
						ss_strided_offset	<= strided_offset[63:32];
					end
					
					2:
					begin
						ss_pc				<= if_pc[95:64];
						ss_instruction		<= if_instruction[95:64];
						ss_branch_predicted <= if_branch_predicted[2];
						ss_long_latency 	<= if_long_latency[2];
						ss_reg_lane_select	<= reg_lane_select[11:8];
						ss_strided_offset	<= strided_offset[95:64];
					end
					
					3:
					begin
						ss_pc				<= if_pc[127:96];
						ss_instruction		<= if_instruction[127:96];
						ss_branch_predicted <= if_branch_predicted[3];
						ss_long_latency 	<= if_long_latency[3];
						ss_reg_lane_select	<= reg_lane_select[15:12];
						ss_strided_offset	<= strided_offset[127:96];
					end
				endcase
				
				ss_strand <= issue_strand_idx;
			end
			else
			begin
				// No strand is ready, issue NOP
				ss_pc 				<= 0;
				ss_instruction 		<= `NOP;
				ss_branch_predicted <= 0;
				ss_long_latency 	<= 0;
			end
		end

`ifdef GENERATE_PROFILE_DATA
		if (ss_instruction != 0)
			$display("%08x", ss_pc);
`endif
	end
endmodule
