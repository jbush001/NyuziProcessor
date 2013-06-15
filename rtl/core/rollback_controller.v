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

//
// Reconcile rollback requests from multiple stages and strands. 
//
// When a rollback occurs, we squash instructions that are earlier in the 
// pipeline and are from the same strand.  Note that multiple rollbacks
// for the same strand may occur in the same cycle.  In this situation, the
// rollback for the oldest PC (one that is farthest down the pipeline) takes
// precedence.
//
// A rollback request does not trigger a squash of the instruction in the stage
// that requested the  rollback. The requesting stage must do that.  This is mainly 
// because of call instructions, which must propagate to the writeback stage to 
// update the link register.
//
// The ex_strandx notation may be confusing:
//    ex_strand refers to the instruction coming out of the execute stage
//    ex_strandn refers to an instruction in the intermediate stage of the 
//	  multi-cycle pipeline, which may be a *later* instruction that ex_strand because
//    the mux acts as a bypass.
//

module rollback_controller(
	// Signals from the pipeline. These indicate current state and rollback
	// requests.
	input [`STRAND_INDEX_WIDTH - 1:0] ss_strand,
	input [`STRAND_INDEX_WIDTH - 1:0] ds_strand,
	input						ex_rollback_request, 	// execute
	input [31:0]				ex_rollback_pc, 
	input [`STRAND_INDEX_WIDTH - 1:0] ex_strand,				// strand coming out of ex stage
	input [`STRAND_INDEX_WIDTH - 1:0] ex_strand1,				// strands in multi-cycle pipeline
	input [`STRAND_INDEX_WIDTH - 1:0] ex_strand2,
	input [`STRAND_INDEX_WIDTH - 1:0] ex_strand3,
	input [31:0]				ma_strided_offset,
	input [3:0]					ma_reg_lane_select,
	input [`STRAND_INDEX_WIDTH - 1:0] ma_strand,
	input						wb_rollback_request, 	// writeback
	input						wb_retry,
	input [31:0]				wb_rollback_pc,
	input						wb_suspend_request,
	
	// Squash signals cancel active instructions in the pipeline
	output reg 					squash_ds,		// decode
	output reg					squash_ex0,		// execute
	output reg					squash_ex1,
	output reg					squash_ex2,
	output reg					squash_ex3,
	output reg					squash_ma,		// memory access

	// These go to the instruction fetch and strand select stages to
	// update the strand's state.
	output [`STRANDS_PER_CORE - 1:0]		rb_rollback_strand,
	output [`STRANDS_PER_CORE * 32 - 1:0]	rb_rollback_pc,
	output [`STRANDS_PER_CORE * 32 - 1:0]	rollback_strided_offset,
	output [`STRANDS_PER_CORE * 4 - 1:0]	rollback_reg_lane,
	output [`STRANDS_PER_CORE - 1:0]		suspend_strand,
	output [`STRANDS_PER_CORE - 1:0]		rb_retry_strand);

	wire[`STRANDS_PER_CORE - 1:0] rollback_wb_str;
	wire[`STRANDS_PER_CORE - 1:0] rollback_ex_str;
	
	genvar strand;
	
	generate
		for (strand = 0; strand < `STRANDS_PER_CORE; strand = strand + 1)
		begin
			assign rollback_wb_str[strand] = wb_rollback_request && ma_strand == strand;	
			assign rollback_ex_str[strand] = ex_rollback_request && ds_strand == strand;
			assign rb_rollback_strand[strand] = rollback_wb_str[strand] || rollback_ex_str[strand];
			assign rb_retry_strand[strand] = rollback_wb_str[strand] && wb_retry;

			assign rb_rollback_pc[(strand + 1) * 32 - 1:strand * 32] = rollback_wb_str[strand]
				? wb_rollback_pc : ex_rollback_pc;
			assign rollback_strided_offset[(strand + 1) * 32 - 1:strand * 32] = rollback_wb_str[strand]
				? ma_strided_offset : 32'd0;
			assign rollback_reg_lane[(strand + 1) * 4 - 1:strand * 4] = rollback_wb_str[strand]
				? ma_reg_lane_select : 4'd0;
			assign suspend_strand[strand] = rollback_wb_str[strand]
				? wb_suspend_request : 1'd0;
		end	
	endgenerate

	always @*
	begin : gensquash
		integer strand;
		
		squash_ma = 0;
		squash_ex0 = 0;
		squash_ex1 = 0;
		squash_ex2 = 0;
		squash_ex3 = 0;
		squash_ds = 0;
	
		for (strand = 0; strand < `STRANDS_PER_CORE; strand = strand + 1)
		begin
			if (rollback_wb_str[strand])
			begin
				// Rollback all instances of this strand earlier in the pipeline
				squash_ma = squash_ma | (ex_strand == strand);
				squash_ex0 = squash_ex0 | (ds_strand == strand);
				squash_ex1 = squash_ex1 | (ex_strand1 == strand);
				squash_ex2 = squash_ex2 | (ex_strand2 == strand);
				squash_ex3 = squash_ex3 | (ex_strand3 == strand);
			end

			if (rb_rollback_strand[strand])
				squash_ds = squash_ds | ss_strand == strand;
		end
	end
endmodule
