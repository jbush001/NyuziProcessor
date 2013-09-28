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
// Queues pending memory stores and issues to L2 cache. 
// This contains the state for all four strands, each of which can independently
// queue a store.
//
// Whenever there is a cache load, this checks to see if a store is pending
// for the same request and forwards the updated data to the writeback
// stage (but only for the strand that issued to the store).
//
// This also tracks synchronized stores.  When a synchronized store is 
// first issued, it will always get rolled back, since it must wait
// for a round trip to the L2 cache. When the ack is received, the strand
// will be restarted and the instruction re-issued.  This tracks the fact
// that the ack has been received and let's the strand continue.
//
// Cache control operations like flushes are also enqueued here. 
//

module store_buffer
	(input 							clk,
	input							reset,
	output reg[`STRANDS_PER_CORE - 1:0] store_resume_strands,
	input [25:0]					request_addr,
	input [511:0]					data_to_dcache,
	input							dcache_store,
	input							dcache_flush,
	input							dcache_dinvalidate,
	input							dcache_iinvalidate,
	input							dcache_stbar,
	input							synchronized_i,
	input [63:0]					dcache_store_mask,
	input [`STRAND_INDEX_WIDTH - 1:0] strand_i,
	output reg[511:0]				data_o,
	output reg[63:0]				mask_o,
	output 							rollback_o,
	output							l2req_valid,
	input							l2req_ready,
	output [1:0]					l2req_unit,
	output [`STRAND_INDEX_WIDTH - 1:0] l2req_strand,
	output [2:0]					l2req_op,
	output [1:0]					l2req_way,
	output [25:0]					l2req_address,
	output [511:0]					l2req_data,
	output [63:0]					l2req_mask,
	input 							l2rsp_valid,
	input							l2rsp_status,
	input [1:0]						l2rsp_unit,
	input [`STRAND_INDEX_WIDTH - 1:0] l2rsp_strand);
	
	reg store_enqueued[0:`STRANDS_PER_CORE - 1];
	reg store_acknowledged[0:`STRANDS_PER_CORE - 1];
	reg[511:0] store_data[0:`STRANDS_PER_CORE - 1];
	reg[63:0] store_mask[0:`STRANDS_PER_CORE - 1];
	reg[25:0] store_address[0:`STRANDS_PER_CORE - 1];
	reg[2:0] store_op[0:`STRANDS_PER_CORE - 1];	// Must match size of l2req_op
	wire[`STRAND_INDEX_WIDTH - 1:0] issue_idx;
	wire[`STRANDS_PER_CORE - 1:0] issue_oh;
	reg[`STRANDS_PER_CORE - 1:0] store_wait_strands;
	reg[`STRANDS_PER_CORE - 1:0] store_finish_strands;
	wire[63:0] raw_mask_nxt;
	wire[511:0] raw_data_nxt;
	reg[`STRANDS_PER_CORE - 1:0] sync_store_wait;
	reg[`STRANDS_PER_CORE - 1:0] sync_store_complete;
	reg strand_must_wait;
	reg[`STRANDS_PER_CORE - 1:0] sync_store_result;
	wire store_collision;
	wire[`STRANDS_PER_CORE - 1:0] l2_ack_mask;
		
	assign raw_mask_nxt = (store_enqueued[strand_i] 
		&& request_addr == store_address[strand_i]) 
		? store_mask[strand_i]
		: 0;
	assign raw_data_nxt = store_data[strand_i];

	wire[`STRANDS_PER_CORE - 1:0] issue_request;

	genvar queue_idx;
	generate
		for (queue_idx = 0; queue_idx < `STRANDS_PER_CORE; queue_idx = queue_idx + 1)
		begin : update_request
			assign issue_request[queue_idx] = store_enqueued[queue_idx] 
				& !store_acknowledged[queue_idx];
		end
	endgenerate

	arbiter #(.NUM_ENTRIES(`STRANDS_PER_CORE)) next_issue(
		.request(issue_request),
		.update_lru(l2req_ready),
		.grant_oh(issue_oh),
		/*AUTOINST*/
							      // Inputs
							      .clk		(clk),
							      .reset		(reset));

	one_hot_to_index #(.NUM_SIGNALS(`STRANDS_PER_CORE)) cvt_issue_idx(
		.one_hot(issue_oh),
		.index(issue_idx));

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

`ifdef SIMULATION
	assert_false #("more than one transaction type specified in store buffer") a4(
		.clk(clk),
		.test(dcache_store + dcache_flush + dcache_dinvalidate + dcache_stbar 
			+ dcache_iinvalidate > 1));
`endif

	// This indicates that a request has come in in the same cycle a request was
	// satisfied. If we suspended the strand, it would hang forever because there
	// would be no event to wake it back up.
	assign store_collision = l2_store_complete && request && strand_i == l2rsp_strand;

`ifdef SIMULATION
	assert_false #("L2 responded to store buffer entry that wasn't issued") a0
		(.clk(clk), .test(l2rsp_valid && l2rsp_unit == `UNIT_STBUF
			&& !store_enqueued[l2rsp_strand]));
	assert_false #("L2 responded to store buffer entry that wasn't acknowledged") a1
		(.clk(clk), .test(l2rsp_valid && l2rsp_unit == `UNIT_STBUF
			&& !store_acknowledged[l2rsp_strand]));
`endif

	always @*
	begin
		if (l2rsp_valid && l2rsp_unit == `UNIT_STBUF)
			store_finish_strands = 1 << l2rsp_strand;
		else
			store_finish_strands = 0;
	end

	wire[`STRANDS_PER_CORE - 1:0] sync_req_mask = (synchronized_i && dcache_store && !store_enqueued[strand_i]) ? (1 << strand_i) : 0;
	assign l2_ack_mask = (l2rsp_valid && l2rsp_unit == `UNIT_STBUF) ? (1 << l2rsp_strand) : 0;
	wire need_sync_rollback = (sync_req_mask & ~sync_store_complete) != 0;
	reg need_sync_rollback_latched;

`ifdef SIMULATION
	assert_false #("blocked strand issued sync store") a2(
		.clk(clk), .test((sync_store_wait & sync_req_mask) != 0));
	assert_false #("store complete and store wait set simultaneously") a3(
		.clk(clk), .test((sync_store_wait & sync_store_complete) != 0));
`endif
	
	assign rollback_o = strand_must_wait || need_sync_rollback_latched;

	always @(posedge clk, posedge reset)
	begin : update
		integer i;
		
		if (reset)
		begin
			for (i = 0; i < `STRANDS_PER_CORE; i = i + 1)
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
			store_resume_strands <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
			store_wait_strands <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
			strand_must_wait <= 1'h0;
			sync_store_complete <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
			sync_store_result <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
			sync_store_wait <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
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
					| (1 << strand_i);
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

`ifdef SIMULATION
	assert_false #("store_acknowledged conflict") a5(.clk(clk),
		.test(issue_oh != 0 && l2req_ready && l2_store_complete && l2rsp_strand 
			== issue_idx));
`endif
endmodule
