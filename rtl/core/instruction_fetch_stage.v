// 
// Copyright 2011-2013 Jeff Bush
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
// Instruction pipeline instruction fetch stage.
// Issues requests to L1 cache to keep the instruction FIFOs (one for each strand) loaded.
// Predict branches, potentially updating PC to follow them
// Pre-decode long-latency arithmetic instructions, passing a flag to the next stage.
//

`include "defines.v"

module instruction_fetch_stage(
	input                                    clk,
	input                                    reset,
	
	// To/From instruction cache
	output [31:0]                            icache_addr,
	input [31:0]                             icache_data,
	input                                    icache_hit,
	output                                   icache_request,
	output [`STRAND_INDEX_WIDTH - 1:0]       icache_req_strand,
	input [`STRANDS_PER_CORE - 1:0]          icache_load_complete_strands,
	input                                    icache_load_collision,

	// To/From strand select stage. Signals for all of the strands are 
	// concatenated together.
	output [`STRANDS_PER_CORE - 1:0]         if_instruction_valid,
	output [`STRANDS_PER_CORE * 32 - 1:0]    if_instruction,
	output [`STRANDS_PER_CORE * 32 - 1:0]    if_pc,
	output [`STRANDS_PER_CORE - 1:0]         if_branch_predicted,
	output [`STRANDS_PER_CORE - 1:0]         if_long_latency,
	input [`STRANDS_PER_CORE - 1:0]          ss_instruction_req,
	
	// From rollback controller
	input [`STRANDS_PER_CORE - 1:0]          rb_rollback_strand,
	input [`STRANDS_PER_CORE * 32 - 1:0]     rb_rollback_pc);

	localparam INSTRUCTION_FIFO_LENGTH = 4;

	logic[31:0] program_counter_ff[0:`STRANDS_PER_CORE - 1];
	logic[31:0] program_counter_nxt[0:`STRANDS_PER_CORE - 1];
	logic[`STRANDS_PER_CORE - 1:0] icache_request_strands;
	logic[`STRANDS_PER_CORE - 1:0] icache_waiting_strands_ff;
	logic[`STRANDS_PER_CORE - 1:0] icache_waiting_strands_nxt;
	
	// This stores the last strand that issued a request to the cache (since results
	// have one cycle of latency, we need to remember this).
	logic[`STRANDS_PER_CORE - 1:0] last_requested_strand_oh;
	logic[`STRANDS_PER_CORE - 1:0] next_request_strand_oh;

	// Issue least recently issued strand.  Don't issue strands that we know are
	// waiting on the cache.
	arbiter #(.NUM_ENTRIES(`STRANDS_PER_CORE)) request_arb(
		.request(icache_request_strands & ~icache_waiting_strands_nxt),
		.update_lru(1'b1),
		.grant_oh(next_request_strand_oh),
		/*AUTOINST*/
							       // Inputs
							       .clk		(clk),
							       .reset		(reset));
	
	assign icache_request = next_request_strand_oh != 0;

	one_hot_to_index #(.NUM_SIGNALS(`STRANDS_PER_CORE)) cvt_cache_request(
		.one_hot(next_request_strand_oh),
		.index(icache_req_strand));

	assign icache_addr = program_counter_nxt[icache_req_strand];
	
	// Keep track of which strands are waiting on an icache fetch.
	always_comb
	begin
		if (!icache_hit && last_requested_strand_oh != 0 && !icache_load_collision)
		begin
			// Cache miss.  Mark the requesting strand as waiting
			icache_waiting_strands_nxt = (icache_waiting_strands_ff 
				& ~icache_load_complete_strands) | last_requested_strand_oh;
		end
		else
		begin
			// Not a cache miss, but still need to clear pending bit for any
			// loads that have completed.
			icache_waiting_strands_nxt = icache_waiting_strands_ff
				& ~icache_load_complete_strands;
		end
	end

	logic[`STRANDS_PER_CORE - 1:0] ififo_almost_full;
	logic[`STRANDS_PER_CORE - 1:0] ififo_full;
	logic[`STRANDS_PER_CORE - 1:0] ififo_empty;	
	wire[`STRANDS_PER_CORE - 1:0] ififo_enqueue = {`STRANDS_PER_CORE{icache_hit}} & last_requested_strand_oh;

	assign icache_request_strands = ~ififo_full & ~(ififo_almost_full & ififo_enqueue);
	assign if_instruction_valid = ~ififo_empty;

	wire[31:0] icache_data_twiddled = { icache_data[7:0], icache_data[15:8], 
		icache_data[23:16], icache_data[31:24] };
	wire is_conditional_branch = icache_data_twiddled[31:28] == 4'b1111
		&& (icache_data_twiddled[27:25] == 3'b000
		|| icache_data_twiddled[27:25] == 3'b001
		|| icache_data_twiddled[27:25] == 3'b010
		|| icache_data_twiddled[27:25] == 3'b101);
	wire[31:0] branch_offset = { {12{icache_data_twiddled[24]}}, icache_data_twiddled[24:5] };

	// Static branch prediction: predict taken if backward
	wire conditional_branch_predicted = branch_offset[31];

`ifdef DISABLE_BRANCH_PREDICTION
	wire branch_predicted = 0;
`else
	wire branch_predicted = icache_data_twiddled[31:25] == 7'b1111_011 // branch always
		|| icache_data_twiddled[31:25] == 7'b1111_100 // call
		|| (is_conditional_branch && conditional_branch_predicted);
`endif

	// Pre-decode instruction to determine if this is a long latency instruction (uses
	// longer arithmetic pipeline).
	logic is_long_latency;
	always_comb
	begin
		if (icache_data_twiddled[31:29] == 3'b110)
		begin
			// Format A instruction
			is_long_latency = icache_data_twiddled[25] == 1
				|| icache_data_twiddled[25:20] == `OP_IMUL;
		end
		else if (icache_data_twiddled[31] == 1'b0)
		begin
			// Format B
			is_long_latency = icache_data_twiddled[27:23] == `OP_IMUL;
		end
		else
			is_long_latency = 0;
	end

	genvar strand_id;
	
	generate
		for (strand_id = 0; strand_id < `STRANDS_PER_CORE; strand_id = strand_id + 1)
		begin : strand
			sync_fifo #(.DATA_WIDTH(66), .NUM_ENTRIES(INSTRUCTION_FIFO_LENGTH)) instruction_fifo(
				.clk(clk),
				.reset(reset),
				.flush_i(rb_rollback_strand[strand_id]),
				.almost_full_o(ififo_almost_full[strand_id]),
				.full_o(ififo_full[strand_id]),
				.enqueue_i(ififo_enqueue[strand_id]),
				.value_i({ program_counter_ff[strand_id] + 32'd4, icache_data_twiddled, 
					branch_predicted, is_long_latency }),
				.empty_o(ififo_empty[strand_id]),
				.dequeue_i(ss_instruction_req[strand_id] && if_instruction_valid[strand_id]),	// FIXME instruction_valid_o is redundant
				.value_o({ if_pc[strand_id * 32+:32], 
					if_instruction[strand_id * 32+:32], 
					if_branch_predicted[strand_id], 
					if_long_latency[strand_id] }),
				.almost_empty_o());	

			// When a cache hit occurs in this cycle, program_counter_ff points to the 
			// instruction that was just fetched.  When a cache miss is occurs, 
			// program_counter_ff points to the next instruction that should be fetched (same
			// as program_counter_nxt). Although it is not completely obvious in this logic, 
			// the next instruction address--be it a predicted branch or the next sequential 
			// instruction--is always resolved in the cycle the instruction is returned from 
			// the cache.
			wire[31:0] strand_program_counter = program_counter_ff[strand_id];
			
			always_comb
			begin
				if (rb_rollback_strand[strand_id])
					program_counter_nxt[strand_id] = rb_rollback_pc[strand_id * 32+:32];
				else if (!icache_hit || !last_requested_strand_oh[strand_id])  
					program_counter_nxt[strand_id] = strand_program_counter;
				else if (branch_predicted)
					program_counter_nxt[strand_id] = strand_program_counter + 32'd4 + branch_offset;  
				else
					program_counter_nxt[strand_id] = strand_program_counter + 32'd4;
			end

			// This shouldn't happen in our simulations normally.  Since it can be hard
			// to detect, check it explicitly.
			// Note that an unaligned memory access will jump to address zero by default
			// if the handler address isn't set, so those will be captured here as well.
			always_ff @(posedge clk)
			begin
				assert(!rb_rollback_strand[strand_id]
					|| rb_rollback_pc[(strand_id + 1) * 32 - 1:strand_id * 32] != 0);
			end
		end
	endgenerate
	

	always_ff @(posedge clk, posedge reset)
	begin : update
		if (reset)
		begin
			for (int i = 0; i < `STRANDS_PER_CORE; i = i + 1)
				program_counter_ff[i] <= 32'h0;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			icache_waiting_strands_ff <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
			last_requested_strand_oh <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
			// End of automatics
		end
		else
		begin
			for (int i = 0; i < `STRANDS_PER_CORE; i = i + 1)
				program_counter_ff[i] <= program_counter_nxt[i];

			last_requested_strand_oh <= next_request_strand_oh;
			icache_waiting_strands_ff <= icache_waiting_strands_nxt;
		end
	end
endmodule
