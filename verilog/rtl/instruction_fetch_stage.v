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
// CPU pipeline instruction fetch stage.
// Issues requests to L1 cache to keep 4 instruction FIFOs (one for each strand) loaded.
//

module instruction_fetch_stage(
	input							clk,
	output reg[31:0]				icache_addr,
	input [31:0]					icache_data,
	input                           icache_hit,
	output							icache_request,
	output [1:0]					icache_req_strand,
	input [3:0]						icache_load_complete_strands,
	input							icache_load_collision,

	output [31:0]					if_instruction0,
	output							if_instruction_valid0,
	output [31:0]					if_pc0,
	output							if_branch_predicted0,
	input							ss_instruction_req0,
	input							rb_rollback_strand0,
	input [31:0]					rb_rollback_pc0,

	output [31:0]					if_instruction1,
	output							if_instruction_valid1,
	output [31:0]					if_pc1,
	output							if_branch_predicted1,
	input							ss_instruction_req1,
	input							rb_rollback_strand1,
	input [31:0]					rb_rollback_pc1,

	output [31:0]					if_instruction2,
	output							if_instruction_valid2,
	output [31:0]					if_pc2,
	output							if_branch_predicted2,
	input							ss_instruction_req2,
	input							rb_rollback_strand2,
	input [31:0]					rb_rollback_pc2,

	output [31:0]					if_instruction3,
	output							if_instruction_valid3,
	output [31:0]					if_pc3,
	output							if_branch_predicted3,
	input							ss_instruction_req3,
	input							rb_rollback_strand3,
	input [31:0]					rb_rollback_pc3);
	
	reg[31:0]						program_counter0_ff = 0;
	reg[31:0]						program_counter0_nxt = 0;
	reg[31:0]						program_counter1_ff = 0;
	reg[31:0]						program_counter1_nxt = 0;
	reg[31:0]						program_counter2_ff = 0;
	reg[31:0]						program_counter2_nxt = 0;
	reg[31:0]						program_counter3_ff = 0;
	reg[31:0]						program_counter3_nxt = 0;
	wire[3:0]						instruction_request;
	reg[3:0]						instruction_cache_wait_ff = 0;
	reg[3:0]						instruction_cache_wait_nxt = 0;

	// This stores the last strand that issued a request to the cache (since results
	// have one cycle of latency, we need to remember this).
	reg[3:0]						cache_request_oh = 0;
	wire[3:0]						cache_request_oh_nxt;

	// Issue least recently issued strand.  Don't issue strands that we know are
	// waiting on the cache.
	arbiter #(4) request_arb(
		.clk(clk),
		.request(instruction_request & ~instruction_cache_wait_nxt),
		.update_lru(1'b1),
		.grant_oh(cache_request_oh_nxt));
	
	assign icache_request = |cache_request_oh_nxt;

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
		if (!icache_hit && cache_request_oh && !icache_load_collision)
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
		&& (icache_data_twiddled[27:24] == 3'b000
		|| icache_data_twiddled[27:24] == 3'b001
		|| icache_data_twiddled[27:24] == 3'b010
		|| icache_data_twiddled[27:24] == 3'b101
		|| icache_data_twiddled[27:24] == 3'b110);
	wire[31:0] branch_offset = { {12{icache_data_twiddled[24]}}, icache_data_twiddled[24:5] };

	// Static branch prediction: predict if backward
	wire conditional_branch_predicted = branch_offset[31];
	wire branch_predicted = icache_data_twiddled[31:25] == 7'b1111_011 // branch always
		|| icache_data_twiddled[31:25] == 7'b1111_100 // call
		|| (is_conditional_branch && conditional_branch_predicted);

	sync_fifo #(65, 2, 1) if0(
		.clk(clk),
		.flush_i(rb_rollback_strand0),
		.almost_full_o(almost_full[0]),
		.full_o(full[0]),
		.enqueue_i(enqueue[0]),
		.value_i({ program_counter0_ff + 32'd4, icache_data_twiddled, branch_predicted }),
		.empty_o(empty[0]),
		.dequeue_i(ss_instruction_req0 && if_instruction_valid0),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc0, if_instruction0, if_branch_predicted0 }));

	sync_fifo #(65, 2, 1) if1(
		.clk(clk),
		.flush_i(rb_rollback_strand1),
		.almost_full_o(almost_full[1]),
		.full_o(full[1]),
		.enqueue_i(enqueue[1]),
		.value_i({ program_counter1_ff + 32'd4, icache_data_twiddled, branch_predicted }),
		.empty_o(empty[1]),
		.dequeue_i(ss_instruction_req1 && if_instruction_valid1),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc1, if_instruction1, if_branch_predicted1 }));

	sync_fifo #(65, 2, 1) if2(
		.clk(clk),
		.flush_i(rb_rollback_strand2),
		.almost_full_o(almost_full[2]),
		.full_o(full[2]),
		.enqueue_i(enqueue[2]),
		.value_i({ program_counter2_ff + 32'd4, icache_data_twiddled, branch_predicted }),
		.empty_o(empty[2]),
		.dequeue_i(ss_instruction_req2 && if_instruction_valid2),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc2, if_instruction2, if_branch_predicted2 }));

	sync_fifo #(65, 2, 1) if3(
		.clk(clk),
		.flush_i(rb_rollback_strand3),
		.almost_full_o(almost_full[3]),
		.full_o(full[3]),
		.enqueue_i(enqueue[3]),
		.value_i({ program_counter3_ff + 32'd4, icache_data_twiddled, branch_predicted }),
		.empty_o(empty[3]),
		.dequeue_i(ss_instruction_req3 && if_instruction_valid3),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc3, if_instruction3, if_branch_predicted3 }));

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

	always @(posedge clk)
	begin
		program_counter0_ff <= #1 program_counter0_nxt;
		program_counter1_ff <= #1 program_counter1_nxt;
		program_counter2_ff <= #1 program_counter2_nxt;
		program_counter3_ff <= #1 program_counter3_nxt;
		cache_request_oh <= #1 cache_request_oh_nxt;
		instruction_cache_wait_ff <= #1 instruction_cache_wait_nxt;
	end

	// This shouldn't happen in our simulations normally.  Since it can be hard
	// to detect, check it explicitly.
	assertion #("thread 0 was rolled back to address 0") a0(.clk(clk),
		.test(rb_rollback_strand0 && rb_rollback_pc0 == 0));
	assertion #("thread 1 was rolled back to address 0") a1(.clk(clk),
		.test(rb_rollback_strand1 && rb_rollback_pc1 == 0));
	assertion #("thread 2 was rolled back to address 0") a2(.clk(clk),
		.test(rb_rollback_strand2 && rb_rollback_pc2 == 0));
	assertion #("thread 3 was rolled back to address 0") a3(.clk(clk),
		.test(rb_rollback_strand3 && rb_rollback_pc3 == 0));
endmodule
