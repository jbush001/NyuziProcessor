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
// L1 Instruction/Data Cache
//
// This is virtually indexed/virtually tagged and non-blocking.
// It has one cycle of latency.  During each cycle, tag memory and
// the four way memory banks are accessed in parallel.  Combinational
// logic them determines which bank the result should be pulled from.
//
// L1 caches are 8k. There are 4 ways, 32 sets, 64 bytes per line
//	   bits 0-5 (6) of address are the offset into the line
//	   bits 6-10 (5) are the set index
//	   bits 11-31 (21) are the tag
//
// Note that the L2 cache controls what is in the L1 cache. When there are misses
// or even stores, we always inform the L2 cache, which pushes lines back into
// the L1 cache.
//

module l1_cache
	#(parameter UNIT_ID = 0)
	(input						clk,
	input						reset,
	
	// To core
	input						access_i,
	input [25:0]				request_addr,
	input [1:0]					strand_i,
	input						synchronized_i,
	output reg[511:0]			data_o,
	output						cache_hit_o,
	output [3:0]				load_complete_strands_o,
	output						load_collision_o,

	// L2 interface
	output						l2req_valid,
	input						l2req_ready,
	output [1:0]				l2req_unit,
	output [1:0]				l2req_strand,
	output [2:0]				l2req_op,
	output [1:0]				l2req_way,
	output [25:0]				l2req_address,
	output [511:0]				l2req_data,
	output [63:0]				l2req_mask,
	input 						l2rsp_valid,
	input [1:0]					l2rsp_unit,
	input [1:0]					l2rsp_strand,
	input [1:0]					l2rsp_way,
	input [1:0]					l2rsp_op,
	input [25:0]				l2rsp_address,
	input 						l2rsp_update,
	input [511:0]				l2rsp_data);
	
	wire[1:0] lru_way;
	reg access_latched;
	reg	synchronized_latched;
	reg[25:0] request_addr_latched;
	reg[1:0] strand_latched;
	wire[511:0] way0_read_data;
	wire[511:0] way1_read_data;
	wire[511:0] way2_read_data;
	wire[511:0]way3_read_data;
	reg load_collision1;
	wire[1:0] hit_way;
	wire data_in_cache;
	reg[3:0] sync_load_wait;
	reg[3:0] sync_load_complete;

	wire[`L1_SET_INDEX_WIDTH - 1:0] requested_set = request_addr[`L1_SET_INDEX_WIDTH - 1:0];

	wire[`L1_SET_INDEX_WIDTH - 1:0] l2_response_set = l2rsp_address[`L1_SET_INDEX_WIDTH - 1:0];
	wire[`L1_TAG_WIDTH - 1:0] l2_response_tag = l2rsp_address[25:`L1_SET_INDEX_WIDTH];

	wire got_load_response = l2rsp_valid && l2rsp_unit == UNIT_ID 
		&& l2rsp_op == `L2RSP_LOAD_ACK;

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
		&& ((l2rsp_op == `L2RSP_LOAD_ACK && l2rsp_unit == UNIT_ID) 
		|| (l2rsp_op == `L2RSP_STORE_ACK && l2rsp_update && UNIT_ID == `UNIT_DCACHE));

	wire update_way0_data = update_data && l2rsp_way == 0;
	sram_1r1w #(512, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH) way0_data(
		.clk(clk),
		.rd_addr(requested_set),
		.rd_data(way0_read_data),
		.rd_enable(access_i),
		.wr_addr(l2_response_set),
		.wr_data(l2rsp_data),
		.wr_enable(update_way0_data));

	wire update_way1_data = update_data && l2rsp_way == 1;
	sram_1r1w #(512, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH) way1_data(
		.clk(clk),
		.rd_addr(requested_set),
		.rd_data(way1_read_data),
		.rd_enable(access_i),
		.wr_addr(l2_response_set),
		.wr_data(l2rsp_data),
		.wr_enable(update_way1_data));

	wire update_way2_data = update_data && l2rsp_way == 2;
	sram_1r1w #(512, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH) way2_data(
		.clk(clk),
		.rd_addr(requested_set),
		.rd_data(way2_read_data),
		.rd_enable(access_i),
		.wr_addr(l2_response_set),
		.wr_data(l2rsp_data),
		.wr_enable(update_way2_data));

	wire update_way3_data = update_data && l2rsp_way == 3;
	sram_1r1w #(512, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH) way3_data(
		.clk(clk),
		.rd_addr(requested_set),
		.rd_data(way3_read_data),
		.rd_enable(access_i),
		.wr_addr(l2_response_set),
		.wr_data(l2rsp_data),
		.wr_enable(update_way3_data));

	// We've fetched the value from all four ways in parallel.  Now
	// we know which way contains the data we care about, so select
	// that one.
	always @*
	begin
		case (hit_way)
			0: data_o = way0_read_data;
			1: data_o = way1_read_data;
			2: data_o = way2_read_data;
			3: data_o = way3_read_data;
		endcase
	end

	// If there is a hit, move that way to the MRU.	 If there is a miss,
	// move the victim way to the MRU position so it doesn't get evicted on 
	// the next data access.
	wire[1:0] new_mru_way = data_in_cache ? hit_way : lru_way;
	wire update_mru = data_in_cache || (access_latched && !data_in_cache);
	
	cache_lru #(`L1_NUM_SETS, `L1_SET_INDEX_WIDTH) lru(
		.set_i(requested_set),
		.lru_way_o(lru_way),
		/*AUTOINST*/
							   // Inputs
							   .clk			(clk),
							   .reset		(reset),
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
	wire[1:0] load_way = synchronized_latched && data_in_cache ? 
		hit_way : lru_way;

	wire[3:0] sync_req_mask = (access_i && synchronized_i) ? (4'b0001 << strand_i) : 4'd0;
	wire[3:0] sync_ack_mask = (l2rsp_valid && l2rsp_unit == UNIT_ID) ? (4'b0001 << l2rsp_strand) : 4'd0;

	assert_false #("blocked strand issued sync load") a0(
		.clk(clk), .test((sync_load_wait & sync_req_mask) != 0));
	assert_false #("load complete and load wait set simultaneously") a1(
		.clk(clk), .test((sync_load_wait & sync_load_complete) != 0));

	// Synchronized accesses always take a cache miss on the first load
	assign cache_hit_o = data_in_cache && !need_sync_rollback;

	load_miss_queue #(UNIT_ID) load_miss_queue(
		.clk(clk),
		.request_i(queue_cache_load),
		.synchronized_i(synchronized_latched),
		.request_addr(request_addr_latched),
		.victim_way_i(load_way),
		.strand_i(strand_latched),
		/*AUTOINST*/
						   // Outputs
						   .load_complete_strands_o(load_complete_strands_o[3:0]),
						   .l2req_valid		(l2req_valid),
						   .l2req_unit		(l2req_unit[1:0]),
						   .l2req_strand	(l2req_strand[1:0]),
						   .l2req_op		(l2req_op[2:0]),
						   .l2req_way		(l2req_way[1:0]),
						   .l2req_address	(l2req_address[25:0]),
						   .l2req_data		(l2req_data[511:0]),
						   .l2req_mask		(l2req_mask[63:0]),
						   // Inputs
						   .reset		(reset),
						   .l2req_ready		(l2req_ready),
						   .l2rsp_valid		(l2rsp_valid),
						   .l2rsp_unit		(l2rsp_unit[1:0]),
						   .l2rsp_strand	(l2rsp_strand[1:0]));

	// Performance counters
	reg[63:0] hit_count;
	reg[63:0] miss_count;

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			access_latched <= 1'h0;
			hit_count <= 64'h0;
			load_collision1 <= 1'h0;
			miss_count <= 64'h0;
			need_sync_rollback <= 1'h0;
			request_addr_latched <= 26'h0;
			strand_latched <= 2'h0;
			sync_load_complete <= 4'h0;
			sync_load_wait <= 4'h0;
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
			sync_load_wait <= (sync_load_wait | (sync_req_mask & ~sync_load_complete)) & ~sync_ack_mask;
			sync_load_complete <= (sync_load_complete | sync_ack_mask) & ~sync_req_mask;
			need_sync_rollback <= (sync_req_mask & ~sync_load_complete) != 0;
	
			// Performance counters
			if (access_latched && !load_collision_o)
			begin
				if (cache_hit_o)
					hit_count <= hit_count + 1;
				else
					miss_count <= miss_count + 1;
			end
		end
	end
endmodule
