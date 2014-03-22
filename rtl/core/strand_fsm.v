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
// Strand finite state machine. 
//
// This tracks the state of a single strand.  It will keep track of cache misses 
// and restart a strand when it receives updates from the L1 cache.
//
// This also handles delaying strands when there are RAW/WAW conflicts (because of 
// memory loads or long latency instructions). Currently, we don't detect these 
// conflicts explicitly but always delay the next instruction when one of these
// instructions that could generate a RAW is issue_strand_ohd.
//
// There are three types of rollbacks, which are encoded as follows:
//
// +------------------------+-------------+------------+----------+
// | Type                   | rollback    |  suspend   |  retry   |
// +------------------------+-------------+------------+----------+
// | mispredicted branch    |       1     |      0     |    0     |
// | retry                  |       1     |      0     |    1     |
// | dcache miss/stbuf full |       1     |      1     |    0     |
// +------------------------+-------------+------------+----------+
//
// A retry occurs when a cache fill completes in the same cycle that a 
// cache miss occurs for the same line.  We don't suspend the strand because
// the miss is satisfied, but we need to restart it to pick up the data.
//

module strand_fsm(
	input             clk,
	input             reset,

	// To/From instruction fetch stage
	output            ss_instruction_req,
	input             if_instruction_valid,	// if_instruction is valid
	input [31:0]      if_instruction,
	input             if_long_latency,
	
	// From strand select stage
	output            strand_ready,
	input             issue_strand_oh, // we have permission to issue_strand_oh (based on strand_ready, watch for loop)

	// To decode stage
	output [3:0]      reg_lane_select,
	output [31:0]     strided_offset,

	// From downstream execution units.  Signals to suspend/resume strand.
	input             rb_rollback_strand,
	input             rb_suspend_strand,
	input             rb_retry_strand,
	input             resume_strand,
	input [31:0]      rb_rollback_strided_offset,
	input [3:0]       rb_rollback_reg_lane);

	typedef enum {
		STATE_STRAND_READY,
		STATE_VECTOR_LOAD, 
		STATE_VECTOR_STORE,
		STATE_RAW_WAIT,
		STATE_CACHE_WAIT
	} thread_state_t;

	logic[3:0] load_delay_ff;
	logic[3:0] load_delay_nxt;
	thread_state_t thread_state_ff;
	thread_state_t thread_state_nxt;
	logic[31:0] strided_offset_nxt;
	logic[3:0] reg_lane_select_ff ;
	logic[3:0] reg_lane_select_nxt;
	logic[31:0] strided_offset_ff; 

	wire is_fmt_c = if_instruction[31:30] == 2'b10;
	fmtc_op_t fmtc_op = fmtc_op_t'(if_instruction[28:25]);
	wire is_load = if_instruction[29]; // Assumes fmt c
	wire is_synchronized_store = !is_load && fmtc_op == MEM_SYNC;	// assumes fmt c
	wire is_multi_cycle_transfer = is_fmt_c 
		&& (fmtc_op == MEM_STRIDED
		|| fmtc_op == MEM_STRIDED_M
		|| fmtc_op == MEM_STRIDED_IM
		|| fmtc_op == MEM_SCGATH
		|| fmtc_op == MEM_SCGATH_M
		|| fmtc_op == MEM_SCGATH_IM);
	wire is_masked = (fmtc_op == MEM_STRIDED_M
		|| fmtc_op == MEM_STRIDED_IM
		|| fmtc_op == MEM_SCGATH_M
		|| fmtc_op == MEM_SCGATH_IM
		|| fmtc_op == MEM_BLOCK_M
		|| fmtc_op == MEM_BLOCK_IM);
		
	wire vector_transfer_end = reg_lane_select_ff == 0 && thread_state_ff != STATE_CACHE_WAIT;
	wire is_vector_transfer = thread_state_ff == STATE_VECTOR_LOAD || thread_state_ff == STATE_VECTOR_STORE
	   || is_multi_cycle_transfer;
	assign ss_instruction_req = ((thread_state_ff == STATE_STRAND_READY 
		&& !is_multi_cycle_transfer)
		|| (is_vector_transfer && vector_transfer_end)) && issue_strand_oh;
	wire will_issue_strand_oh = if_instruction_valid && issue_strand_oh;
	assign strand_ready = thread_state_ff != STATE_RAW_WAIT
		&& thread_state_ff != STATE_CACHE_WAIT
		&& if_instruction_valid
		&& !rb_rollback_strand;

	// When a load occurs, there is a potential RAW dependency.  We just insert nops 
	// to cover that.  A more efficient implementation could detect when a true 
	// dependency exists.
	always_comb
	begin
		if (thread_state_ff == STATE_RAW_WAIT)
			load_delay_nxt = load_delay_ff - 1;
		else 
			load_delay_nxt = 3; 
	end
	
	always_comb
	begin
		if (rb_suspend_strand || rb_retry_strand)
		begin
			reg_lane_select_nxt = rb_rollback_reg_lane;
			strided_offset_nxt = rb_rollback_strided_offset;
		end
		else if (rb_rollback_strand || (vector_transfer_end && will_issue_strand_oh))
		begin
			reg_lane_select_nxt = 4'd15;
			strided_offset_nxt = 0;
		end
		else if (((thread_state_ff == STATE_VECTOR_LOAD || thread_state_ff == STATE_VECTOR_STORE)
		  || is_multi_cycle_transfer) 
		  && thread_state_ff != STATE_CACHE_WAIT
		  && thread_state_ff != STATE_RAW_WAIT
		  && will_issue_strand_oh)
		begin
			reg_lane_select_nxt = reg_lane_select_ff - 1;
			strided_offset_nxt = strided_offset_ff + (is_masked 
				? if_instruction[24:15]
				: if_instruction[24:10]);
		end
		else
		begin
			reg_lane_select_nxt = reg_lane_select_ff;
			strided_offset_nxt = strided_offset_ff;
		end
	end

	always_comb
	begin
		if (rb_rollback_strand)
		begin
			if (rb_suspend_strand)
				thread_state_nxt = STATE_CACHE_WAIT;
			else
				thread_state_nxt = STATE_STRAND_READY;
		end
		else
		begin
			thread_state_nxt = thread_state_ff;
		
			unique case (thread_state_ff)
				STATE_STRAND_READY:
				begin
					// Only update state machine if this is a valid instruction
					if (will_issue_strand_oh && is_fmt_c)
					begin
						// Memory transfer
						if (is_multi_cycle_transfer && !vector_transfer_end)
						begin
							// Vector transfer
							if (is_load)
								thread_state_nxt = STATE_VECTOR_LOAD;
							else
								thread_state_nxt = STATE_VECTOR_STORE;
						end
						else if (is_load || is_synchronized_store)
							thread_state_nxt = STATE_RAW_WAIT;	
					end
					else if (if_long_latency && will_issue_strand_oh)
						thread_state_nxt = STATE_RAW_WAIT;	// long latency instruction
				end
				
				STATE_VECTOR_LOAD:
				begin
					if (vector_transfer_end)
						thread_state_nxt = STATE_RAW_WAIT;
				end
				
				STATE_VECTOR_STORE:
				begin
					if (vector_transfer_end)
						thread_state_nxt = STATE_STRAND_READY;
				end
				
				STATE_RAW_WAIT:
				begin
					if (load_delay_ff == 1)
						thread_state_nxt = STATE_STRAND_READY;
				end
				
				STATE_CACHE_WAIT:
				begin
					if (resume_strand)
						thread_state_nxt = STATE_STRAND_READY;
				end
			endcase
		end
	end

	assign reg_lane_select = reg_lane_select_ff;
	assign strided_offset = strided_offset_ff;
	
`ifdef SIMULATION
	// Thread state breakdown counters
	integer raw_wait_count = 0;
	integer dcache_wait_count = 0;
	integer icache_wait_count = 0;
	
	always_ff @(posedge clk)
	begin
		if (thread_state_ff == STATE_RAW_WAIT)
			raw_wait_count <= raw_wait_count + 1;
		else if (thread_state_ff == STATE_CACHE_WAIT)
			dcache_wait_count <= dcache_wait_count + 1;
		else if (!if_instruction_valid)
			icache_wait_count <= icache_wait_count + 1;
	end
`endif
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			reg_lane_select_ff <= {$clog2(`VECTOR_LANES){1'b1}};
			thread_state_ff <= STATE_STRAND_READY;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			load_delay_ff <= 4'h0;
			strided_offset_ff <= 32'h0;
			// End of automatics
		end
		else
		begin
			// resume request for strand that is not waiting
			assert(!(thread_state_ff != STATE_CACHE_WAIT && resume_strand));
		
			// simultaneous resume and suspend
			assert(!(rb_rollback_strand && resume_strand));

			// simultaneous suspend and retry
			assert(!(rb_rollback_strand && rb_suspend_strand && rb_retry_strand));

			// retry/suspend without rollback
			assert(!(!rb_rollback_strand && (rb_suspend_strand || rb_retry_strand)));

			if (rb_rollback_strand)
				load_delay_ff				<= 0;
			else
				load_delay_ff				<= load_delay_nxt;
	
			thread_state_ff					<= thread_state_nxt;
			reg_lane_select_ff				<= reg_lane_select_nxt;
			strided_offset_ff				<= strided_offset_nxt;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

