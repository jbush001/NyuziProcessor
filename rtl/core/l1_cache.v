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
// L1 Instruction/Data Cache
//
// This is virtually indexed/virtually tagged and non-blocking.
// It has one cycle of latency.  During each cycle, tag memory and
// the four way memory banks are accessed in parallel.  Combinational
// logic them determines which bank the result should be pulled from.
//
// The input address is treated as follows:
//
//  [ tag ] [ set ] [ offset into line (6 bits) ]
//
// set has a configurable number of bits.  The tag is whatever bits remain.
//
// Note that the L2 cache controls what is in the L1 cache. When there are misses
// or even stores, we always inform the L2 cache, which pushes lines back into
// the L1 cache.
//

module l1_cache
	#(parameter UNIT_ID = 0,
	parameter CORE_ID = 0)
	(input                               clk,
	input                                reset,
	
	// From memory access stage
	input                                access_i,
	input [25:0]                         request_addr,
	input [`STRAND_INDEX_WIDTH - 1:0]    strand_i,
	input                                synchronized_i,

	// To writeback stage
	output [`CACHE_LINE_BITS - 1:0]      data_o,
	output                               cache_hit_o,
	output                               load_collision_o,
	
	// To strand select stage
	output [`STRANDS_PER_CORE - 1:0]     load_complete_strands_o,

	// L2 interface
	output                               l2req_valid,
	input                                l2req_ready,
	output [1:0]                         l2req_unit,
	output [`STRAND_INDEX_WIDTH - 1:0]   l2req_strand,
	output [2:0]                         l2req_op,
	output [`L1_WAY_INDEX_WIDTH - 1:0]   l2req_way,
	output [25:0]                        l2req_address,
	output [`CACHE_LINE_BITS - 1:0]      l2req_data,
	output [`CACHE_LINE_BYTES - 1:0]     l2req_mask,
	input                                l2rsp_valid,
	input [`CORE_INDEX_WIDTH - 1:0]      l2rsp_core,
	input [1:0]                          l2rsp_unit,
	input [`STRAND_INDEX_WIDTH - 1:0]    l2rsp_strand,
	input [`L1_WAY_INDEX_WIDTH - 1:0]    l2rsp_way,
	input [1:0]                          l2rsp_op,
	input [25:0]                         l2rsp_address,
	input                                l2rsp_update,
	input [`CACHE_LINE_BITS - 1:0]       l2rsp_data,
	
	// Performance counter event
	output reg                           pc_event_cache_hit,
	output reg                           pc_event_cache_miss);
	
	wire[`L1_WAY_INDEX_WIDTH - 1:0] lru_way;
	reg access_latched;
	reg	synchronized_latched;
	reg[25:0] request_addr_latched;
	reg[`STRAND_INDEX_WIDTH - 1:0] strand_latched;
	reg load_collision1;
	wire[`L1_WAY_INDEX_WIDTH - 1:0] hit_way;
	wire data_in_cache;
	reg[`STRANDS_PER_CORE - 1:0] sync_load_wait;
	reg[`STRANDS_PER_CORE - 1:0] sync_load_complete;

	wire is_for_me = l2rsp_unit == UNIT_ID && l2rsp_core == CORE_ID;
	wire[`L1_SET_INDEX_WIDTH - 1:0] requested_set = request_addr[`L1_SET_INDEX_WIDTH - 1:0];

	wire[`L1_SET_INDEX_WIDTH - 1:0] l2_response_set = l2rsp_address[`L1_SET_INDEX_WIDTH - 1:0];
	wire[`L1_TAG_WIDTH - 1:0] l2_response_tag = l2rsp_address[25:`L1_SET_INDEX_WIDTH];

	wire got_load_response = l2rsp_valid && is_for_me && l2rsp_op == `L2RSP_LOAD_ACK;

	// l2rsp_update indicates if a L1 tag should be cleared for an dinvalidate
	// response
	wire invalidate_one_way = l2rsp_valid && l2rsp_op == `L2RSP_DINVALIDATE
		&& UNIT_ID == `UNIT_DCACHE && l2rsp_update;
	wire invalidate_all_ways = l2rsp_valid && UNIT_ID == `UNIT_ICACHE && l2rsp_op
		== `L2RSP_IINVALIDATE;
	l1_cache_tag tag_mem(
		.hit_way_o(hit_way),
		.cache_hit_o(data_in_cache),
		.update_i(got_load_response),	
		.update_way_i(l2rsp_way),
		.update_tag_i(l2_response_tag),
		.update_set_i(l2_response_set),
		/*AUTOINST*/
			     // Inputs
			     .clk		(clk),
			     .reset		(reset),
			     .request_addr	(request_addr[25:0]),
			     .access_i		(access_i),
			     .invalidate_one_way(invalidate_one_way),
			     .invalidate_all_ways(invalidate_all_ways));

	// Check the unit for loads to differentiate between icache and dcache.
	// We don't check the unit for store acks
	wire update_data = l2rsp_valid 
		&& ((l2rsp_op == `L2RSP_LOAD_ACK && is_for_me) 
		|| (l2rsp_op == `L2RSP_STORE_ACK && l2rsp_update && UNIT_ID == `UNIT_DCACHE));

	wire[`CACHE_LINE_BITS - 1:0] way_read_data[0:`L1_NUM_WAYS - 1];
	genvar way;
	generate
		for (way = 0; way < `L1_NUM_WAYS; way = way + 1)
		begin : makeway
			sram_1r1w #(.DATA_WIDTH(512), .SIZE(`L1_NUM_SETS)) way_data (
				.clk(clk),
				.rd_addr(requested_set),
				.rd_data(way_read_data[way]),
				.rd_enable(access_i),
				.wr_addr(l2_response_set),
				.wr_data(l2rsp_data),
				.wr_enable(update_data && l2rsp_way == way));
		end
	endgenerate

	// We've fetched the value from all four ways in parallel.  Now
	// we know which way contains the data we care about, so select
	// that one.
	assign data_o = way_read_data[hit_way];

	// If there is a hit, move that way to the MRU.	 If there is a miss,
	// move the victim way to the MRU position so it doesn't get evicted on 
	// the next data access.
	wire[`L1_WAY_INDEX_WIDTH - 1:0] new_mru_way = data_in_cache ? hit_way : lru_way;
	wire update_mru = data_in_cache || (access_latched && !data_in_cache);
	
	cache_lru #(.NUM_SETS(`L1_NUM_SETS)) lru(
		.set_i(requested_set),
		.lru_way_o(lru_way),
		/*AUTOINST*/
						 // Inputs
						 .clk			(clk),
						 .reset			(reset),
						 .access_i		(access_i),
						 .new_mru_way		(new_mru_way[1:0]),
						 .update_mru		(update_mru));

	// A load collision occurs when the L2 cache returns a specific cache line
	// in the same cycle we are about to request one. The L1 cache guarantees 
	// that it will not re-request a line when one is already L1 resident or
	// one has been requested.  The load_miss_queue handles the second part of this,
	// and the first part is automatic when the line is already loaded, but
	// there is an edge case where the pending request is neither in the load_miss_queue
	// (being cleared now), nor in the cache data (hasn't been latched yet).
	// Detect that here.
	wire load_collision2 = got_load_response
		&& l2rsp_address == request_addr_latched
		&& access_latched;

	reg need_sync_rollback;

	// Note: do not mark as a load collision if we need a rollback for
	// a synchronized load command (which effectively forces an L2 read 
	// even if the data is present).
	assign load_collision_o = (load_collision1 || load_collision2)
		&& !need_sync_rollback;	

	// Note that a synchronized load always queues a load from the L2 cache,
	// even if the data is in the cache. It must do that to guarantee atomicity.
	wire queue_cache_load = (need_sync_rollback || !data_in_cache) 
		&& access_latched && !load_collision_o;

	// If we do a synchronized load and this is a cache hit, re-load
	// data into the same way that is it is already in.  Otherwise, suggest
	// the LRU way to the L2 cache.
	wire[`L1_WAY_INDEX_WIDTH - 1:0] load_way = synchronized_latched && data_in_cache ? 
		hit_way : lru_way;

	wire[`STRANDS_PER_CORE - 1:0] sync_req_oh = (access_i && synchronized_i) ? (1 << strand_i) : 0;
	wire[`STRANDS_PER_CORE - 1:0] sync_ack_oh = ((l2rsp_valid && is_for_me) ? (1 << l2rsp_strand) : 0)
		& sync_load_wait;

`ifdef SIMULATION
	assert_false #("blocked strand issued sync load") a0(
		.clk(clk), .test((sync_load_wait & sync_req_oh) != 0));
	assert_false #("load complete and load wait set simultaneously") a1(
		.clk(clk), .test((sync_load_wait & sync_load_complete) != 0));
`endif

	// Synchronized accesses always take a cache miss on the first load
	assign cache_hit_o = data_in_cache && !need_sync_rollback;

	l1_load_miss_queue #(.UNIT_ID(UNIT_ID)) load_miss_queue(
		.clk(clk),
		.request_i(queue_cache_load),
		.synchronized_i(synchronized_latched),
		.request_addr(request_addr_latched),
		.victim_way_i(load_way),
		.strand_i(strand_latched),
	   .l2rsp_valid(l2rsp_valid && l2rsp_core == CORE_ID),
		/*AUTOINST*/
								// Outputs
								.load_complete_strands_o(load_complete_strands_o[`STRANDS_PER_CORE-1:0]),
								.l2req_valid	(l2req_valid),
								.l2req_unit	(l2req_unit[1:0]),
								.l2req_strand	(l2req_strand[`STRAND_INDEX_WIDTH-1:0]),
								.l2req_op	(l2req_op[2:0]),
								.l2req_way	(l2req_way[`L1_WAY_INDEX_WIDTH-1:0]),
								.l2req_address	(l2req_address[25:0]),
								.l2req_data	(l2req_data[`CACHE_LINE_BITS-1:0]),
								.l2req_mask	(l2req_mask[`CACHE_LINE_BYTES-1:0]),
								// Inputs
								.reset		(reset),
								.l2req_ready	(l2req_ready),
								.is_for_me	(is_for_me),
								.l2rsp_strand	(l2rsp_strand[`STRAND_INDEX_WIDTH-1:0]));

	// Performance counter events
	always @*
	begin
		pc_event_cache_hit = 0;
		pc_event_cache_miss = 0;
		if (access_latched && !load_collision_o)
		begin
			if (cache_hit_o)
				pc_event_cache_hit = 1;
			else if (!need_sync_rollback)
				pc_event_cache_miss = 1;
		end
	end

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			access_latched <= 1'h0;
			load_collision1 <= 1'h0;
			need_sync_rollback <= 1'h0;
			request_addr_latched <= 26'h0;
			strand_latched <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			sync_load_complete <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
			sync_load_wait <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
			synchronized_latched <= 1'h0;
			// End of automatics
		end
		else
		begin
			// A bit of a kludge to work around a hazard where a request
			// is made in the same cycle a load finishes of the same line.
			// It will not be in tag ram, but if a load is initiated, we'll
			// end up with the cache data in 2 ways.
			load_collision1 <= got_load_response
				&& l2rsp_address == request_addr
				&& access_i;
	
			access_latched <= access_i;
			synchronized_latched <= synchronized_i;
			request_addr_latched <= request_addr;
			strand_latched <= strand_i;
			sync_load_wait <= ((sync_load_wait & ~sync_ack_oh) | (sync_req_oh & ~sync_load_complete));
			sync_load_complete <= (sync_load_complete | sync_ack_oh) & ~sync_req_oh;
			need_sync_rollback <= (sync_req_oh & ~sync_load_complete) != 0;
		end
	end
endmodule
