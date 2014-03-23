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
	#(parameter unit_id_t CORE_ID = 0)

	(input                                clk,
	input                                 reset,
	output logic[`STRANDS_PER_CORE - 1:0] store_resume_strands,
	input [25:0]                          request_addr,
	input [`CACHE_LINE_BITS - 1:0]        data_to_dcache,
	input                                 dcache_store,
	input                                 dcache_flush,
	input                                 dcache_dinvalidate,
	input                                 dcache_iinvalidate,
	input                                 dcache_stbar,
	input                                 synchronized_i,
	input [`CACHE_LINE_BYTES - 1:0]       dcache_store_mask,
	input [`STRAND_INDEX_WIDTH - 1:0]     strand_i,
	output logic[`CACHE_LINE_BITS - 1:0]  data_o,
	output logic[`CACHE_LINE_BYTES - 1:0] mask_o,
	output                                rollback_o,
	input                                 l2req_ready,
	output l2req_packet_t                 l2req_packet,
	input l2rsp_packet_t                  l2rsp_packet);
	
	typedef struct packed {
		logic enqueued;
		logic[`CACHE_LINE_BITS - 1:0] data;
		logic[`CACHE_LINE_BYTES - 1:0] mask;
		logic[25:0] address;
		l2req_packet_type_t op;	
	} store_buffer_entry_t;
	
	store_buffer_entry_t store_buffer_entry[`STRANDS_PER_CORE];
	logic[`STRAND_INDEX_WIDTH - 1:0] issue_idx;
	logic[`STRANDS_PER_CORE - 1:0] issue_oh;
	logic[`CACHE_LINE_BYTES - 1:0] raw_mask_nxt;
	logic[`CACHE_LINE_BITS - 1:0] raw_data_nxt;
	logic strand_must_wait;
	logic store_collision;
	logic[`STRANDS_PER_CORE - 1:0] sync_store_result;
		
	assign raw_mask_nxt = (store_buffer_entry[strand_i].enqueued 
		&& request_addr == store_buffer_entry[strand_i].address) 
		? store_buffer_entry[strand_i].mask
		: 0;
	assign raw_data_nxt = store_buffer_entry[strand_i].data;

	logic[`STRANDS_PER_CORE - 1:0] issue_request;

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
	
	assign l2req_packet = '{
		valid : |issue_oh,
		op : store_buffer_entry[issue_idx].op,
		core : CORE_ID,
		unit : UNIT_STBUF,
		strand : issue_idx,
		way : 0, // Ignored by L2 cache (It knows the way from its directory)
		address : store_buffer_entry[issue_idx].address,
		mask : store_buffer_entry[issue_idx].mask,
		data : store_buffer_entry[issue_idx].data
	};

	wire l2_store_response_valid = l2rsp_packet.valid && l2rsp_packet.unit == UNIT_STBUF 
		&& store_buffer_entry[l2rsp_packet.strand].enqueued;

	wire request = dcache_stbar || dcache_store || dcache_flush
		|| dcache_dinvalidate || dcache_iinvalidate;

	// This indicates that a request has come in in the same cycle a request was
	// satisfied. If we suspended the strand, it would hang forever because there
	// would be no event to wake it back up.
	assign store_collision = l2_store_response_valid && request && strand_i == l2rsp_packet.strand;

	logic[`STRANDS_PER_CORE - 1:0] need_sync_rollback;
	logic need_sync_rollback_latched;

	assign rollback_o = strand_must_wait || need_sync_rollback_latched;

	always_ff @(posedge clk, posedge reset)
	begin : update
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			data_o <= {(1+(`CACHE_LINE_BITS-1)){1'b0}};
			mask_o <= {(1+(`CACHE_LINE_BYTES-1)){1'b0}};
			need_sync_rollback_latched <= 1'h0;
			strand_must_wait <= 1'h0;
			// End of automatics
		end
		else
		begin
			// More than one transaction requested
			assert($onehot0({dcache_store, dcache_flush, dcache_dinvalidate, dcache_stbar,
				dcache_iinvalidate}));

			// L2 responded to store buffer entry that wasn't issued
			assert(!(l2rsp_packet.valid && l2rsp_packet.unit == UNIT_STBUF
				&& !store_buffer_entry[l2rsp_packet.strand].enqueued));

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
			strand_must_wait <= request && store_buffer_entry[strand_i].enqueued && !store_collision;
	
			// Handle synchronized stores (this occurs on the restarted instruction
			// after we've received a response from the L2 cache.  On the first pass,
			// this result is unused because the thread will always be rolled back).
			if (synchronized_i && dcache_store)
			begin
				// Synchronized store result. This utilizes the store bypass mechanism
				// to forward its results to the result register.
				mask_o <= {`CACHE_LINE_BYTES{1'b1}};
				data_o <= {`CACHE_LINE_WORDS{31'd0, sync_store_result[strand_i]}};
			end
			else
			begin
				mask_o <= raw_mask_nxt;
				data_o <= raw_data_nxt;
			end
	
			need_sync_rollback_latched <= |need_sync_rollback;
		end
	end

	genvar strand_idx;
	generate
		for (strand_idx = 0; strand_idx < `STRANDS_PER_CORE; strand_idx++)
		begin : stbuf_entry
			logic wait_sync_store_result;
			logic got_sync_store_result;
			logic store_accepted;
			logic wait_stbuf_full;

			wire sync_req = dcache_store && synchronized_i && (!store_buffer_entry[strand_idx].enqueued
				|| store_collision) && strand_i == strand_idx;
			wire l2_response_this_entry = l2rsp_packet.valid && l2rsp_packet.unit == UNIT_STBUF 
				&& l2rsp_packet.strand == strand_idx;
			assign need_sync_rollback[strand_idx] = sync_req && !got_sync_store_result;
			assign issue_request[strand_idx] = store_buffer_entry[strand_idx].enqueued 
				&& !store_accepted;

			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
				begin
					store_buffer_entry[strand_idx] <= 0;
					store_resume_strands[strand_idx] <= 0;
					sync_store_result[strand_idx] <= 0;
					got_sync_store_result <= 1'h0;
					store_accepted <= 1'h0;
					wait_stbuf_full <= 1'h0;
					wait_sync_store_result <= 1'h0;
				end
				else
				begin
					// synchronized store and store result in same cycle
					assert(!(wait_sync_store_result && l2_response_this_entry && sync_req));

					// store complete and store wait in same cycle
					assert(!(wait_sync_store_result && got_sync_store_result));
					
					// Blocked strand issues store sync
					assert((wait_sync_store_result & sync_req) == 0);
				
					// store accepted conflict
					assert(!(issue_oh[strand_idx] && l2req_ready && l2_store_response_valid 
						&& l2rsp_packet.strand == strand_idx));

					// L2 responded to store buffer entry that wasn't acknowledged
					assert(!(l2rsp_packet.valid && l2rsp_packet.unit == UNIT_STBUF
						&& strand_idx == l2rsp_packet.strand && !store_accepted));


					// Set a signal if the thread needs to be suspended because the
					// store buffer is full.
					if (request && store_buffer_entry[strand_idx].enqueued && strand_i == strand_idx
						&& !store_collision)
						wait_stbuf_full <= 1'b1; 
					else if (l2_response_this_entry)
						wait_stbuf_full <= 1'b0;
					
					// Handle enqueueing new requests. If a synchronized write has not
					// been acknowledged, queue it, but if we've already received an
					// acknowledgement, just return the proper value.
					// Note that stbar will not actually enqueue anything.
					if ((request && !dcache_stbar) 
						&& strand_i == strand_idx
						&& (!store_buffer_entry[strand_idx].enqueued || store_collision)
						&& (!synchronized_i || need_sync_rollback))
					begin	
						store_buffer_entry[strand_idx].enqueued <= 1;
						store_buffer_entry[strand_idx].address <= request_addr;	
						store_buffer_entry[strand_idx].data <= data_to_dcache;
						if (dcache_store)
							store_buffer_entry[strand_idx].mask <= dcache_store_mask;
						else
							store_buffer_entry[strand_idx].mask <= 0; // Don't bypass garbage for non-updating commands

						if (dcache_iinvalidate)
							store_buffer_entry[strand_idx].op <= L2REQ_IINVALIDATE;
						else if (dcache_dinvalidate)
							store_buffer_entry[strand_idx].op <= L2REQ_DINVALIDATE;
						else if (dcache_flush)
							store_buffer_entry[strand_idx].op <= L2REQ_FLUSH;
						else if (synchronized_i)
							store_buffer_entry[strand_idx].op <= L2REQ_STORE_SYNC;
						else
							store_buffer_entry[strand_idx].op <= L2REQ_STORE;
					end
					else if (l2_store_response_valid && !store_collision && l2rsp_packet.strand == strand_idx)
						store_buffer_entry[strand_idx].enqueued <= 0;

					// Update state if a request was accepted by L2 cache
					if (issue_oh[strand_idx] != 0 && l2req_ready)
						store_accepted <= 1'b1;
					else if (l2_store_response_valid && l2rsp_packet.strand == strand_idx)
						store_accepted <= 1'b0;

					// We always delay this a cycle so it will occur after a suspend.
					store_resume_strands[strand_idx] <= l2_response_this_entry && 
						(wait_stbuf_full || wait_sync_store_result);

					// Track synchronized stores
					if (sync_req && !got_sync_store_result)
						wait_sync_store_result <= 1'b1;
					else if (wait_sync_store_result && l2_response_this_entry)
						wait_sync_store_result <= 1'b0;

					if (wait_sync_store_result && l2_response_this_entry)
					begin
						got_sync_store_result <= 1'b1;
						sync_store_result[strand_idx] <= l2rsp_packet.status;
					end
					else if (sync_req) 
						got_sync_store_result <= 1'b0;
				end
			end
		end
	endgenerate
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

