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

module l1_cache
	#(parameter UNIT_ID = 0)
	(input						clk,
	
	// To core
	input [31:0]				address_i,
	output reg[511:0]			data_o = 0,
	input [1:0]					strand_i,
	input						access_i,
	input						synchronized_i,
	output						cache_hit_o,
	output [3:0]				load_complete_strands_o,
	input[`L1_SET_INDEX_WIDTH - 1:0] store_update_set_i,
	input						store_update_i,
	output						load_collision_o,
	
	// L2 interface
	output						pci_valid,
	input						pci_ack,
	output [1:0]				pci_unit,
	output [1:0]				pci_strand,
	output [2:0]				pci_op,
	output [1:0]				pci_way,
	output [25:0]				pci_address,
	output [511:0]				pci_data,
	output [63:0]				pci_mask,
	input 						cpi_valid,
	input [1:0]					cpi_unit,
	input [1:0]					cpi_strand,
	input [1:0]					cpi_way,
	input [511:0]				cpi_data);
	
	reg[1:0]					new_mru_way = 0;
	wire[1:0]					lru_way;
	reg							access_latched = 0;
	reg							synchronized_latched = 0;
	reg[`L1_SET_INDEX_WIDTH - 1:0] request_set_latched = 0;
	reg[`L1_TAG_WIDTH - 1:0]	request_tag_latched = 0;
	reg[1:0]					strand_latched = 0;
	wire[1:0]					load_complete_way;
	wire[`L1_SET_INDEX_WIDTH - 1:0] load_complete_set;
	wire[`L1_TAG_WIDTH - 1:0]	load_complete_tag;
	wire[511:0]					way0_read_data;
	wire[511:0]					way1_read_data;
	wire[511:0]					way2_read_data;
	wire[511:0]					way3_read_data;
	reg							load_collision1 = 0;
	wire[1:0]					hit_way;
	wire 						data_in_cache;
	reg[3:0]					sync_load_wait = 0;
	reg[3:0]					sync_load_complete = 0;

	wire[`L1_SET_INDEX_WIDTH - 1:0] requested_set = address_i[10:6];
	wire[`L1_TAG_WIDTH - 1:0] 		requested_tag = address_i[31:11];

	l1_cache_tag tag_mem(
		.clk(clk),
		.address_i(address_i),
		.access_i(access_i),
		.hit_way_o(hit_way),
		.cache_hit_o(data_in_cache),
		.update_i(|load_complete_strands_o),		// If a load has completed, mark tag valid
		.invalidate_i(0),	// XXX write invalidate will affect this.
		.update_way_i(load_complete_way),
		.update_tag_i(load_complete_tag),
		.update_set_i(load_complete_set));

	wire update_way0 = cpi_valid 
		&& ((load_complete_strands_o != 0 && load_complete_way == 0)
		|| (store_update_i && cpi_way == 0));
	sram_1r1w #(512, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) way0_data(
		.clk(clk),
		.rd_addr(requested_set),
		.rd_data(way0_read_data),
		.wr_addr(load_complete_strands_o != 0 ? load_complete_set : store_update_set_i),
		.wr_data(cpi_data),
		.wr_enable(update_way0));

	wire update_way1 = cpi_valid 
		&& ((load_complete_strands_o != 0 && load_complete_way == 1)
		|| (store_update_i && cpi_way == 1));
	sram_1r1w #(512, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) way1_data(
		.clk(clk),
		.rd_addr(requested_set),
		.rd_data(way1_read_data),
		.wr_addr(load_complete_strands_o != 0 ? load_complete_set : store_update_set_i),
		.wr_data(cpi_data),
		.wr_enable(update_way1));

	wire update_way2 = cpi_valid 
		&& ((load_complete_strands_o != 0 && load_complete_way == 2)
		|| (store_update_i && cpi_way == 2));
	sram_1r1w #(512, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) way2_data(
		.clk(clk),
		.rd_addr(requested_set),
		.rd_data(way2_read_data),
		.wr_addr(load_complete_strands_o != 0 ? load_complete_set : store_update_set_i),
		.wr_data(cpi_data),
		.wr_enable(update_way2));

	wire update_way3 = cpi_valid 
		&& ((load_complete_strands_o != 0 && load_complete_way == 3)
		|| (store_update_i && cpi_way == 3));
	sram_1r1w #(512, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) way3_data(
		.clk(clk),
		.rd_addr(requested_set),
		.rd_data(way3_read_data),
		.wr_addr(load_complete_strands_o != 0 ? load_complete_set : store_update_set_i),
		.wr_data(cpi_data),
		.wr_enable(update_way3));

	always @(posedge clk)
	begin
		access_latched 			<= #1 access_i;
		synchronized_latched	<= #1 synchronized_i;
		request_set_latched 	<= #1 requested_set;
		request_tag_latched		<= #1 requested_tag;
		strand_latched			<= #1 strand_i;
	end

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
	always @*
	begin
		if (data_in_cache)
			new_mru_way = hit_way;
		else
			new_mru_way = lru_way;
	end

	wire update_mru = data_in_cache || (access_latched && !data_in_cache);
	
	cache_lru #(`L1_NUM_SETS, `L1_SET_INDEX_WIDTH) lru(
		.clk(clk),
		.new_mru_way(new_mru_way),
		.set_i(requested_set),
		.update_mru(update_mru),
		.lru_way_o(lru_way));

	// A bit of a kludge to work around a hazard where a request
	// is made in the same cycle a load finishes of the same line.
	// It will not be in tag ram, but if a load is initiated, we'll
	// end up with the cache data in 2 ways.
	always @(posedge clk)
	begin
		load_collision1 <= #1 (load_complete_strands_o != 0
			&& load_complete_tag == requested_tag
			&& load_complete_set == requested_set 
			&& access_i);
	end

	wire load_collision2 = load_complete_strands_o != 0
		&& load_complete_tag == request_tag_latched
		&& load_complete_set == request_set_latched
		&& access_latched;

	// Note: do not mark as a load collision if we need a rollback for
	// a synchronized load command (which effectively forces an L2 read 
	// even if the data is present).
	assign load_collision_o = (load_collision1 || load_collision2)
		&& !need_sync_rollback;	

	// Note that a synchronized load always queues a load from the L2 cache,
	// even if the data is in the cache.
	wire queue_cache_load = (need_sync_rollback || !data_in_cache) 
		&& access_latched && !load_collision_o;

	// If we do a synchronized load and this is a cache hit, re-load
	// data into the same way.
	wire[1:0] load_way = synchronized_latched && data_in_cache ? 
		hit_way : lru_way;

	wire[3:0] sync_req_mask = (access_i && synchronized_i) ? (4'b0001 << strand_i) : 4'd0;
	wire[3:0] sync_ack_mask = (cpi_valid && cpi_unit == UNIT_ID) ? (4'b0001 << cpi_strand) : 4'd0;
	reg need_sync_rollback = 0;

	assertion #("blocked strand issued sync load") a0(
		.clk(clk), .test((sync_load_wait & sync_req_mask) != 0));
	assertion #("load complete and load wait set simultaneously") a1(
		.clk(clk), .test((sync_load_wait & sync_load_complete) != 0));

	always @(posedge clk)
	begin
		sync_load_wait <= #1 (sync_load_wait | (sync_req_mask & ~sync_load_complete)) & ~sync_ack_mask;
		sync_load_complete <= #1 (sync_load_complete | sync_ack_mask) & ~sync_req_mask;
		need_sync_rollback <= #1 (sync_req_mask & ~sync_load_complete) != 0;
	end

	// Synchronized accesses always take a cache miss on the first load
	assign cache_hit_o = data_in_cache && !need_sync_rollback;

	load_miss_queue #(UNIT_ID) load_miss_queue(
		.clk(clk),
		.request_i(queue_cache_load),
		.synchronized_i(synchronized_latched),
		.tag_i(request_tag_latched),
		.set_i(request_set_latched),
		.victim_way_i(load_way),
		.strand_i(strand_latched),
		/*AUTOINST*/
						   // Outputs
						   .load_complete_strands_o(load_complete_strands_o[3:0]),
						   .load_complete_set	(load_complete_set[`L1_SET_INDEX_WIDTH-1:0]),
						   .load_complete_tag	(load_complete_tag[`L1_TAG_WIDTH-1:0]),
						   .load_complete_way	(load_complete_way[1:0]),
						   .pci_valid		(pci_valid),
						   .pci_unit		(pci_unit[1:0]),
						   .pci_strand		(pci_strand[1:0]),
						   .pci_op		(pci_op[2:0]),
						   .pci_way		(pci_way[1:0]),
						   .pci_address		(pci_address[25:0]),
						   .pci_data		(pci_data[511:0]),
						   .pci_mask		(pci_mask[63:0]),
						   // Inputs
						   .pci_ack		(pci_ack),
						   .cpi_valid		(cpi_valid),
						   .cpi_unit		(cpi_unit[1:0]),
						   .cpi_strand		(cpi_strand[1:0]));

	//// Performance Counters /////////////////
	reg[63:0] hit_count = 0;
	reg[63:0] miss_count = 0;

	always @(posedge clk)
	begin
		if (access_latched && !load_collision_o)
		begin
			if (cache_hit_o)
				hit_count <= #1 hit_count + 1;
			else
				miss_count <= #1 miss_count + 1;
		end
	end
	
	/////////////////////////////////////////////
endmodule
