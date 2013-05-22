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
// Instruction pipeline instruction fetch stage.
// Issues requests to L1 cache to keep 4 instruction FIFOs (one for each strand) loaded.
// Predict branches, potentially updating PC to follow them
// Pre-decode long-latency arithmetic instructions, passing a flag to the next stage.
//

`include "defines.v"

module instruction_fetch_stage(
	input							clk,
	input							reset,
	
	output[31:0]					DEBUG_pc0,
	
	// To/From instruction cache
	output reg[31:0]				icache_addr,
	input [31:0]					icache_data,
	input                           icache_hit,
	output							icache_request,
	output [1:0]					icache_req_strand,
	input [3:0]						icache_load_complete_strands,
	input							icache_load_collision,

	// Outputs to strand select stage
	output [31:0]					if_instruction0,
	output							if_instruction_valid0,
	output [31:0]					if_pc0,
	output							if_branch_predicted0,
	output							if_long_latency0,
	input							ss_instruction_req0,
	input							rb_rollback_strand0,
	input [31:0]					rb_rollback_pc0,

	output [31:0]					if_instruction1,
	output							if_instruction_valid1,
	output [31:0]					if_pc1,
	output							if_branch_predicted1,
	output							if_long_latency1,
	input							ss_instruction_req1,
	input							rb_rollback_strand1,
	input [31:0]					rb_rollback_pc1,

	output [31:0]					if_instruction2,
	output							if_instruction_valid2,
	output [31:0]					if_pc2,
	output							if_branch_predicted2,
	output							if_long_latency2,
	input							ss_instruction_req2,
	input							rb_rollback_strand2,
	input [31:0]					rb_rollback_pc2,

	output [31:0]					if_instruction3,
	output							if_instruction_valid3,
	output [31:0]					if_pc3,
	output							if_branch_predicted3,
	output							if_long_latency3,
	input							ss_instruction_req3,
	input							rb_rollback_strand3,
	input [31:0]					rb_rollback_pc3);

	localparam INSTRUCTION_FIFO_LENGTH = 4;

	reg[31:0] program_counter0_ff;
	reg[31:0] program_counter0_nxt;
	reg[31:0] program_counter1_ff;
	reg[31:0] program_counter1_nxt;
	reg[31:0] program_counter2_ff;
	reg[31:0] program_counter2_nxt;
	reg[31:0] program_counter3_ff;
	reg[31:0] program_counter3_nxt;
	wire[3:0] instruction_request;
	reg[3:0] instruction_cache_wait_ff;
	reg[3:0] instruction_cache_wait_nxt;
	
	assign DEBUG_pc0 = program_counter0_ff;

	// This stores the last strand that issued a request to the cache (since results
	// have one cycle of latency, we need to remember this).
	reg[3:0] cache_request_oh;
	wire[3:0] cache_request_oh_nxt;

	// Issue least recently issued strand.  Don't issue strands that we know are
	// waiting on the cache.
	arbiter #(.NUM_ENTRIES(4)) request_arb(
		.request(instruction_request & ~instruction_cache_wait_nxt),
		.update_lru(1'b1),
		.grant_oh(cache_request_oh_nxt),
		/*AUTOINST*/
					       // Inputs
					       .clk		(clk),
					       .reset		(reset));
	
	assign icache_request = cache_request_oh_nxt != 0;

	always @*
	begin
		case (cache_request_oh_nxt)
			4'b1000: icache_addr = program_counter3_nxt;
			4'b0100: icache_addr = program_counter2_nxt;
			4'b0010: icache_addr = program_counter1_nxt;
			4'b0001: icache_addr = program_counter0_nxt;
			4'b0000: icache_addr = program_counter0_nxt;	// Don't care
			default: icache_addr = {32{1'bx}};	// Shouldn't happen
		endcase
	end

	assign icache_req_strand = { cache_request_oh_nxt[2] | cache_request_oh_nxt[3],
		cache_request_oh_nxt[1] | cache_request_oh_nxt[3] };	// Convert one-hot to index
	
	// Keep track of which strands are waiting on an icache fetch.
	always @*
	begin
		if (!icache_hit && cache_request_oh != 0 && !icache_load_collision)
		begin
			instruction_cache_wait_nxt = (instruction_cache_wait_ff 
				& ~icache_load_complete_strands) | cache_request_oh;
		end
		else
		begin
			instruction_cache_wait_nxt = instruction_cache_wait_ff
				& ~icache_load_complete_strands;
		end
	end

	wire[3:0] almost_full;
	wire[3:0] full;
	wire[3:0] empty;	

	wire[3:0] enqueue = {4{icache_hit}} & cache_request_oh;
	assign instruction_request = ~full & ~(almost_full & enqueue);
	assign { if_instruction_valid3, if_instruction_valid2, if_instruction_valid1,
		if_instruction_valid0 } = ~empty;

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
	reg is_long_latency;
	always @*
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

	sync_fifo #(.DATA_WIDTH(66), .NUM_ENTRIES(INSTRUCTION_FIFO_LENGTH)) if0(
		.flush_i(rb_rollback_strand0),
		.almost_full_o(almost_full[0]),
		.full_o(full[0]),
		.enqueue_i(enqueue[0]),
		.value_i({ program_counter0_ff + 32'd4, icache_data_twiddled, branch_predicted, 
			is_long_latency }),
		.empty_o(empty[0]),
		.dequeue_i(ss_instruction_req0 && if_instruction_valid0),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc0, if_instruction0, if_branch_predicted0, if_long_latency0 }),
		.almost_empty_o(),
		/*AUTOINST*/
										// Inputs
										.clk		(clk),
										.reset		(reset));

	sync_fifo #(.DATA_WIDTH(66), .NUM_ENTRIES(INSTRUCTION_FIFO_LENGTH)) if1(
		.flush_i(rb_rollback_strand1),
		.almost_full_o(almost_full[1]),
		.full_o(full[1]),
		.enqueue_i(enqueue[1]),
		.value_i({ program_counter1_ff + 32'd4, icache_data_twiddled, branch_predicted,
			is_long_latency}),
		.empty_o(empty[1]),
		.dequeue_i(ss_instruction_req1 && if_instruction_valid1),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc1, if_instruction1, if_branch_predicted1, if_long_latency1 }),
		.almost_empty_o(),
		/*AUTOINST*/
										// Inputs
										.clk		(clk),
										.reset		(reset));

	sync_fifo #(.DATA_WIDTH(66), .NUM_ENTRIES(INSTRUCTION_FIFO_LENGTH)) if2(
		.flush_i(rb_rollback_strand2),
		.almost_full_o(almost_full[2]),
		.full_o(full[2]),
		.enqueue_i(enqueue[2]),
		.value_i({ program_counter2_ff + 32'd4, icache_data_twiddled, branch_predicted,
			is_long_latency }),
		.empty_o(empty[2]),
		.dequeue_i(ss_instruction_req2 && if_instruction_valid2),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc2, if_instruction2, if_branch_predicted2, if_long_latency2 }),
		.almost_empty_o(),
		/*AUTOINST*/
										// Inputs
										.clk		(clk),
										.reset		(reset));

	sync_fifo #(.DATA_WIDTH(66), .NUM_ENTRIES(INSTRUCTION_FIFO_LENGTH)) if3(
		.flush_i(rb_rollback_strand3),
		.almost_full_o(almost_full[3]),
		.full_o(full[3]),
		.enqueue_i(enqueue[3]),
		.value_i({ program_counter3_ff + 32'd4, icache_data_twiddled, branch_predicted,
			is_long_latency }),
		.empty_o(empty[3]),
		.dequeue_i(ss_instruction_req3 && if_instruction_valid3),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc3, if_instruction3, if_branch_predicted3, if_long_latency3 }),
		.almost_empty_o(),
		/*AUTOINST*/
										// Inputs
										.clk		(clk),
										.reset		(reset));

	// When a cache hit occurs in this cycle, program_counter_ff points to the 
	// instruction that was just fetched.  When a cache miss is occurs, 
	// program_counter_ff points to the next instruction that should be fetched (same
	// as program_counter_nxt). Although it is not completely obvious in this logic, 
	// the next instruction address--be it a predicted branch or the next sequential 
	// instruction--is always resolved in the cycle the instruction is returned from 
	// the cache.

	always @*
	begin
		if (rb_rollback_strand0)
			program_counter0_nxt = rb_rollback_pc0;
		else if (!icache_hit || !cache_request_oh[0])	
			program_counter0_nxt = program_counter0_ff;
		else if (branch_predicted)
			program_counter0_nxt = program_counter0_ff + 32'd4 + branch_offset;	
		else
			program_counter0_nxt = program_counter0_ff + 32'd4;
	end

	always @*
	begin
		if (rb_rollback_strand1)
			program_counter1_nxt = rb_rollback_pc1;
		else if (!icache_hit || !cache_request_oh[1])	
			program_counter1_nxt = program_counter1_ff;
		else if (branch_predicted)
			program_counter1_nxt = program_counter1_ff + 32'd4 + branch_offset;		
		else
			program_counter1_nxt = program_counter1_ff + 32'd4;
	end

	always @*
	begin
		if (rb_rollback_strand2)
			program_counter2_nxt = rb_rollback_pc2;
		else if (!icache_hit || !cache_request_oh[2])	
			program_counter2_nxt = program_counter2_ff;
		else if (branch_predicted)
			program_counter2_nxt = program_counter2_ff + 32'd4 + branch_offset;		
		else
			program_counter2_nxt = program_counter2_ff + 32'd4;
	end

	always @*
	begin
		if (rb_rollback_strand3)
			program_counter3_nxt = rb_rollback_pc3;
		else if (!icache_hit || !cache_request_oh[3])	
			program_counter3_nxt = program_counter3_ff;
		else if (branch_predicted)
			program_counter3_nxt = program_counter3_ff + 32'd4 + branch_offset;	
		else
			program_counter3_nxt = program_counter3_ff + 32'd4;
	end

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			cache_request_oh <= 4'h0;
			instruction_cache_wait_ff <= 4'h0;
			program_counter0_ff <= 32'h0;
			program_counter1_ff <= 32'h0;
			program_counter2_ff <= 32'h0;
			program_counter3_ff <= 32'h0;
			// End of automatics
		end
		else
		begin
			program_counter0_ff <= program_counter0_nxt;
			program_counter1_ff <= program_counter1_nxt;
			program_counter2_ff <= program_counter2_nxt;
			program_counter3_ff <= program_counter3_nxt;
			cache_request_oh <= cache_request_oh_nxt;
			instruction_cache_wait_ff <= instruction_cache_wait_nxt;
		end
	end

	// This shouldn't happen in our simulations normally.  Since it can be hard
	// to detect, check it explicitly.
	// Note that an unaligned memory access will jump to address zero by default
	// if the handler address isn't set, so those will be captured here as well.
	assert_false #("thread 0 was rolled back to address 0") a0(.clk(clk),
		.test(rb_rollback_strand0 && rb_rollback_pc0 == 0));
	assert_false #("thread 1 was rolled back to address 0") a1(.clk(clk),
		.test(rb_rollback_strand1 && rb_rollback_pc1 == 0));
	assert_false #("thread 2 was rolled back to address 0") a2(.clk(clk),
		.test(rb_rollback_strand2 && rb_rollback_pc2 == 0));
	assert_false #("thread 3 was rolled back to address 0") a3(.clk(clk),
		.test(rb_rollback_strand3 && rb_rollback_pc3 == 0));
endmodule
