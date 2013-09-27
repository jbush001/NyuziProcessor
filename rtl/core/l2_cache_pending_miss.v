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
// Tracks pending cache misses in the L2 cache.
// The sole purpose of this module is to avoid having duplicate system memory
// loads/stores.  In the best case, they would be less efficient, but in the worst
// case, a load after store will clobber data.
// Each time a cache miss goes past this unit, it records the cache line 
// that is pending.  When a restarted request goes past this unit, it clears
// the pending line.  For each transaction, the 'duplicate_reqest'
// signal is set to indicate if another transaction for that line is pending.
//
// Bear in mind that the pending miss for the line may be anywhere in the L2 pipeline,
// not just the SMI queue. Because of this, QUEUE_SIZE must be >= the number of 
// entries in the system memory request queue + the number of pipeline stages.
//

module l2_cache_pending_miss
	#(parameter 			QUEUE_SIZE = 16,
	parameter 				QUEUE_ADDR_WIDTH = $clog2(QUEUE_SIZE))
	(input					clk,
	input					reset,
	input					rd_l2req_valid,
	input [25:0]			rd_l2req_address,
	input					enqueue_load_request,
	input					rd_is_l2_fill,
	output 					duplicate_request);

	reg[25:0] miss_address[0:QUEUE_SIZE - 1];
	reg entry_valid[0:QUEUE_SIZE - 1];
	wire[QUEUE_ADDR_WIDTH - 1:0] cam_hit_entry;
	wire cam_hit;
	reg[QUEUE_SIZE - 1:0] empty_entries;	// 1 if entry is empty
	wire[QUEUE_SIZE - 1:0] next_empty_oh = empty_entries & ~(empty_entries - 1);
	wire[QUEUE_ADDR_WIDTH - 1:0] next_empty;
	
	one_hot_to_index #(.NUM_SIGNALS(QUEUE_SIZE)) cvt(
		.one_hot(next_empty_oh),
		.index(next_empty));

	assert_false #("Pending miss queue full") a(
		.clk(clk), 
		.test(!reset && empty_entries == 0));

	assign duplicate_request = cam_hit;

	cam #(.NUM_ENTRIES(QUEUE_SIZE), .KEY_WIDTH(26)) lookup_cam(
		.clk(clk),
		.reset(reset),
		.lookup_key(rd_l2req_address),
		.lookup_index(cam_hit_entry),
		.lookup_hit(cam_hit),
		.update_en(rd_l2req_valid && (cam_hit ? rd_is_l2_fill
			: enqueue_load_request)),
		.update_key(rd_l2req_address),
		.update_index(cam_hit ? cam_hit_entry : next_empty),
		.update_valid(cam_hit ? !rd_is_l2_fill : enqueue_load_request));

	always @(posedge clk, posedge reset)
	begin
		if (reset)
			empty_entries <= {QUEUE_SIZE{1'b1}};
		else if (cam_hit & rd_is_l2_fill)
			empty_entries[cam_hit_entry] <= 1'b1;
		else if (!cam_hit && enqueue_load_request)
			empty_entries[next_empty] <= 1'b0;
	end
endmodule
