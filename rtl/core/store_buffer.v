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

`include "l2_cache.h"

//
// Queues pending memory stores and issues to L2 cache.
// Whenever there is a cache load, this checks to see if a store is pending
// for the same request and bypasses the data.
//
// This also tracks synchronized stores.  These get rolled back on the first
// request, since we must wait for a response from the L2 cache to make sure
// the L1 cache line has proper data in it.  When the strand is restarted, we 
// need to keep track of the fact that we already got an L2 ack and let the 
// strand continue lest we get into an infinite rollback loop.
//
// Cache operations like flushes are also enqueued here. 
//

module store_buffer
	(input 							clk,
	input							reset,
	output reg[3:0]					store_resume_strands,
	input [25:0]					request_addr,
	input [511:0]					data_to_dcache,
	input							dcache_store,
	input							dcache_flush,
	input							dcache_dinvalidate,
	input							dcache_iinvalidate,
	input							dcache_stbar,
	input							synchronized_i,
	input [63:0]					dcache_store_mask,
	input [1:0]						strand_i,
	output reg[511:0]				data_o,
	output reg[63:0]				mask_o,
	output 							rollback_o,
	output							l2req_valid,
	input							l2req_ready,
	output [1:0]					l2req_unit,
	output [1:0]					l2req_strand,
	output [2:0]					l2req_op,
	output [1:0]					l2req_way,
	output [25:0]					l2req_address,
	output [511:0]					l2req_data,
	output [63:0]					l2req_mask,
	input 							l2rsp_valid,
	input							l2rsp_status,
	input [1:0]						l2rsp_unit,
	input [1:0]						l2rsp_strand);
	
	reg								store_enqueued[0:3];
	reg								store_acknowledged[0:3];
	reg[511:0]						store_data[0:3];
	reg[63:0]						store_mask[0:3];
	reg[25:0] 						store_address[0:3];
	reg[2:0]						store_op[0:3];	// Must match size of l2req_op
	wire[1:0]						issue_idx;
	wire[3:0]						issue_oh;
	reg[3:0]						store_wait_strands;
	integer							i;
	reg[3:0]						store_finish_strands;
	integer							j;
	reg[63:0]						raw_mask_nxt;
	reg[511:0]						raw_data_nxt;
	reg[3:0]						sync_store_wait;
	reg[3:0]						sync_store_complete;
	reg								strand_must_wait;
	reg[3:0]						sync_store_result;
	reg[63:0] 						store_count;	// Performance counter
	wire							store_collision;
	wire[3:0] 						l2_ack_mask;
		
	// Store RAW handling. We only bypass results from the same strand.
	always @*
	begin
		raw_mask_nxt = 0;		
		raw_data_nxt = 0;

		for (j = 0; j < 4; j = j + 1)
		begin
			if (store_enqueued[j] && request_addr == store_address[j] && strand_i == j)
			begin
				raw_mask_nxt = store_mask[j];
				raw_data_nxt = store_data[j];
			end
		end
	end

	arbiter #(4) next_issue(
		.request({ store_enqueued[3] & !store_acknowledged[3],
			store_enqueued[2] & !store_acknowledged[2],
			store_enqueued[1] & !store_acknowledged[1],
			store_enqueued[0] & !store_acknowledged[0] }),
		.update_lru(l2req_ready),
		.grant_oh(issue_oh),
		/*AUTOINST*/
				// Inputs
				.clk		(clk),
				.reset		(reset));

	assign issue_idx = { issue_oh[3] || issue_oh[2], issue_oh[3] || issue_oh[1] };

	assign l2req_op = store_op[issue_idx];
	assign l2req_unit = `UNIT_STBUF;
	assign l2req_strand = issue_idx;
	assign l2req_data = store_data[issue_idx];
	assign l2req_address = store_address[issue_idx];
	assign l2req_mask = store_mask[issue_idx];
	assign l2req_way = 0;	// Ignored by L2 cache (It knows the way from its directory)
	assign l2req_valid = |issue_oh;

	wire l2_store_complete = l2rsp_valid && l2rsp_unit == `UNIT_STBUF && store_enqueued[l2rsp_strand];

	wire request = dcache_stbar || dcache_store || dcache_flush
		|| dcache_dinvalidate || dcache_iinvalidate;

	assert_false #("more than one transaction type specified in store buffer") a4(
		.clk(clk),
		.test(dcache_store + dcache_flush + dcache_dinvalidate + dcache_stbar 
			+ dcache_iinvalidate > 1));

	// This indicates that a request has come in in the same cycle a request was
	// satisfied. If we suspended the strand, it would hang forever because there
	// would be no event to wake it back up.
	assign store_collision = l2_store_complete && request && strand_i == l2rsp_strand;

	assert_false #("L2 responded to store buffer entry that wasn't issued") a0
		(.clk(clk), .test(l2rsp_valid && l2rsp_unit == `UNIT_STBUF
			&& !store_enqueued[l2rsp_strand]));
	assert_false #("L2 responded to store buffer entry that wasn't acknowledged") a1
		(.clk(clk), .test(l2rsp_valid && l2rsp_unit == `UNIT_STBUF
			&& !store_acknowledged[l2rsp_strand]));

	always @*
	begin
		if (l2rsp_valid && l2rsp_unit == `UNIT_STBUF)
			store_finish_strands = 4'b0001 << l2rsp_strand;
		else
			store_finish_strands = 0;
	end

	wire[3:0] sync_req_mask = (synchronized_i && dcache_store && !store_enqueued[strand_i]) ? (4'b0001 << strand_i) : 4'd0;
	assign l2_ack_mask = (l2rsp_valid && l2rsp_unit == `UNIT_STBUF) ? (4'b0001 << l2rsp_strand) : 4'd0;
	wire need_sync_rollback = (sync_req_mask & ~sync_store_complete) != 0;
	reg need_sync_rollback_latched;

	assert_false #("blocked strand issued sync store") a2(
		.clk(clk), .test((sync_store_wait & sync_req_mask) != 0));
	assert_false #("store complete and store wait set simultaneously") a3(
		.clk(clk), .test((sync_store_wait & sync_store_complete) != 0));
	
	assign rollback_o = strand_must_wait || need_sync_rollback_latched;

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (i = 0; i < 4; i = i + 1)
			begin
				store_enqueued[i] <= 0;
				store_acknowledged[i] <= 0;
				store_data[i] <= 0;
				store_mask[i] <= 0;
				store_address[i] <= 0;
				store_op[i] <= 0;
			end

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			data_o <= 512'h0;
			mask_o <= 64'h0;
			need_sync_rollback_latched <= 1'h0;
			store_count <= 64'h0;
			store_resume_strands <= 4'h0;
			store_wait_strands <= 4'h0;
			strand_must_wait <= 1'h0;
			sync_store_complete <= 4'h0;
			sync_store_result <= 4'h0;
			sync_store_wait <= 4'h0;
			// End of automatics
		end
		else
		begin
			// Check if we need to roll back a strand because the store buffer is 
			// full.  Track which strands are waiting and provide an output
			// signal.
			//
			// Note that stbar will only block the strand if there is already one
			// queued in the store buffer (which is what we want).  
			//
			// XXX Flush and invalidate only block if the store buffer is full. These
			// need to be followed by a stbar to wait for them to complete.  The
			// reason is that the processor will go into an infinite loop because
			// rollback always returns to the current PC.  We would need to
			// differentiate between the different cases and advance to the next
			// PC in the case where we were waiting for a response from the L2 cache.
			if (request && store_enqueued[strand_i] && !store_collision)
			begin
				// Make this strand wait.
				store_wait_strands <= (store_wait_strands & ~store_finish_strands)
					| (4'b0001 << strand_i);
				strand_must_wait <= 1;
			end
			else
			begin
				store_wait_strands <= store_wait_strands & ~store_finish_strands;
				strand_must_wait <= 0;
			end
	
			// We always delay this a cycle so it will occur after a suspend.
			store_resume_strands <= (store_finish_strands & store_wait_strands)
				| (l2_ack_mask & sync_store_wait);
	
			// Handle synchronized stores
			if (synchronized_i && dcache_store)
			begin
				// Synchronized store
				mask_o <= {64{1'b1}};
				data_o <= {16{31'd0, sync_store_result[strand_i]}};
			end
			else
			begin
				mask_o <= raw_mask_nxt;
				data_o <= raw_data_nxt;
			end
	
			// Handle enqueueing new requests.  If a synchronized write has not
			// been acknowledged, queue it, but if we've already received an
			// acknowledgement, just return the proper value.
			if ((request && !dcache_stbar) && (!store_enqueued[strand_i] || store_collision)
				&& (!synchronized_i || need_sync_rollback))
			begin
				// Performance counter
				if (dcache_store)
					store_count <= store_count + 1;
	
				store_address[strand_i] <= request_addr;	
				if (dcache_flush)
					store_mask[strand_i] <= 0;	// Don't bypass garbage for flushes.
				else
					store_mask[strand_i] <= dcache_store_mask;

				store_enqueued[strand_i] <= 1;
				store_data[strand_i] <= data_to_dcache;

				if (dcache_iinvalidate)
					store_op[strand_i] <= `L2REQ_IINVALIDATE;
				else if (dcache_dinvalidate)
					store_op[strand_i] <= `L2REQ_DINVALIDATE;
				else if (dcache_flush)
					store_op[strand_i] <= `L2REQ_FLUSH;
				else if (synchronized_i)
					store_op[strand_i] <= `L2REQ_STORE_SYNC;
				else
					store_op[strand_i] <= `L2REQ_STORE;
			end
	
			// Update state if a request was issued
			if (issue_oh != 0 && l2req_ready)
				store_acknowledged[issue_idx] <= 1;
	
			if (l2_store_complete)
			begin
				if (!store_collision)
					store_enqueued[l2rsp_strand] <= 0;
	
				store_acknowledged[l2rsp_strand] <= 0;
			end
	
			// Keep track of synchronized stores
			sync_store_wait <= (sync_store_wait | (sync_req_mask & ~sync_store_complete)) & ~l2_ack_mask;
			sync_store_complete <= (sync_store_complete | (sync_store_wait & l2_ack_mask)) & ~sync_req_mask;
			if ((l2_ack_mask & sync_store_wait) != 0)
				sync_store_result[l2rsp_strand] <= l2rsp_status;
	
			need_sync_rollback_latched <= need_sync_rollback;
		end
	end

	assert_false #("store_acknowledged conflict") a5(.clk(clk),
		.test(issue_oh != 0 && l2req_ready && l2_store_complete && l2rsp_strand 
			== issue_idx));
endmodule
