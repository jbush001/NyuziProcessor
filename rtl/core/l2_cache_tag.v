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
// L2 cache tag check stage.
// All of the cache metadata is stored here.  We issue requests to those SRAMs
// here.  They all have latency of one cycle, so the result will be checked
// in the next stage.  The following data is stored here:
//  - LRU information for each of the L2 cache sets.
//  - Valid bits and tag information for each of the L2 cache lines.
//  - Dirty bits for each of the L2 cache lines.
//  - Directories for each of the L1 data caches (which mirror tag information
//    in the latter).
//
// The next stage will set signals which come back that control updating of these
// memories.
//  

module l2_cache_tag
	(input                                        clk,
	input                                         reset,
	input l2req_packet_t                          arb_l2req_packet,
	input                                         arb_is_restarted_request,
	input [`CACHE_LINE_BITS - 1:0]                arb_data_from_memory,
	output l2req_packet_t                         tag_l2req_packet,
	output logic                                  tag_is_restarted_request,
	output logic[`CACHE_LINE_BITS - 1:0]          tag_data_from_memory,
	output logic[1:0]                             tag_miss_fill_l2_way,
	output [`L2_TAG_WIDTH * `L2_NUM_WAYS - 1:0]   tag_l2_tag,
	output [`L2_NUM_WAYS - 1:0]                   tag_l2_valid,
	output [`L2_NUM_WAYS - 1:0]                   tag_l2_dirty,
	output [`NUM_CORES - 1:0]                     tag_l1_has_line,
	output [`NUM_CORES * 2 - 1:0]                 tag_l1_way,
	input                                         dir_update_tag_enable,
	input                                         dir_update_tag_valid,
	input [`L2_TAG_WIDTH - 1:0]                   dir_update_tag_tag,
	input [`L2_SET_INDEX_WIDTH - 1:0]             dir_update_tag_set,
	input [1:0]                                   dir_update_tag_way,
	input [`L2_SET_INDEX_WIDTH - 1:0]             dir_update_dirty_set,
	input                                         dir_new_dirty,
	input [`L2_NUM_WAYS - 1:0]                    dir_update_dirty,
	input [`CORE_INDEX_WIDTH - 1:0]               dir_update_dir_core,
	input                                         dir_update_directory,
	input                                         dir_update_dir_valid, 
	input [1:0]                                   dir_update_dir_way,
	input [`L1_TAG_WIDTH - 1:0]                   dir_update_dir_tag, 
	input [`L1_SET_INDEX_WIDTH - 1:0]             dir_update_dir_set,
	input [1:0]                                   dir_hit_l2_way,
	output                                        pc_event_store);

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = arb_l2req_packet.address[`L2_SET_INDEX_WIDTH - 1:0];

	assign pc_event_store = arb_l2req_packet.valid && !arb_is_restarted_request
		&& (arb_l2req_packet.op == L2REQ_STORE || arb_l2req_packet.op == L2REQ_STORE_SYNC);

	logic[1:0] l2_lru_way;
	cache_lru #(.NUM_SETS(`L2_NUM_SETS)) lru(
		.clk(clk),
		.reset(reset),
		.access_i(arb_l2req_packet.valid),
		.new_mru_way(tag_is_restarted_request ? l2_lru_way : dir_hit_l2_way),
		.set_i(requested_l2_set),
		.update_mru(tag_l2req_packet.valid),
		.lru_way_o(l2_lru_way));

	// Tag ways
	logic[`L2_NUM_WAYS - 1:0] update_tag_way;
	genvar way_index;
	generate
		for (way_index = 0; way_index < `L2_NUM_WAYS; way_index = way_index + 1)
		begin : way
			assign update_tag_way[way_index] = dir_update_tag_enable 
				&& dir_update_tag_way == way_index;

			cache_valid_array #(.NUM_SETS(`L2_NUM_SETS)) l2_valid_mem(
				.clk(clk),
				.reset(reset),
				.rd_enable(arb_l2req_packet.valid),
				.rd_addr(requested_l2_set),
				.rd_is_valid(tag_l2_valid[way_index]),
				.wr_addr(dir_update_tag_set),
				.wr_is_valid(dir_update_tag_valid),
				.wr_enable(update_tag_way[way_index]));

			sram_1r1w #(.DATA_WIDTH(`L2_TAG_WIDTH), .SIZE(`L2_NUM_SETS)) l2_tag_mem(
				.clk(clk),
				.rd_addr(requested_l2_set),
				.rd_data(tag_l2_tag[way_index * `L2_TAG_WIDTH +:`L2_TAG_WIDTH]),
				.rd_enable(arb_l2req_packet.valid),
				.wr_addr(dir_update_tag_set),
				.wr_data(dir_update_tag_tag),
				.wr_enable(update_tag_way[way_index]));

			sram_1r1w #(.DATA_WIDTH(1), .SIZE(`L2_NUM_SETS)) l2_dirty_mem(
				.clk(clk),
				.rd_addr(requested_l2_set),
				.rd_data(tag_l2_dirty[way_index]),
				.rd_enable(arb_l2req_packet.valid),
				.wr_addr(dir_update_dirty_set),
				.wr_data(dir_new_dirty),
				.wr_enable(dir_update_dirty[way_index]));
		end
	endgenerate
	
	// The directory is basically a clone of the tag memories for all core's L1 data
	// caches.
	genvar core_index;
	generate 
		for (core_index = 0; core_index < `NUM_CORES; core_index = core_index + 1)
		begin : core_dir
			l1_cache_tag directory(
				.clk(clk),
				.reset(reset),
				.request_addr(arb_l2req_packet.address),
				.access_i(arb_l2req_packet.valid),
				.cache_hit_o(tag_l1_has_line[core_index]),
				.hit_way_o(tag_l1_way[core_index * `L1_WAY_INDEX_WIDTH+:`L1_WAY_INDEX_WIDTH]),
				.invalidate_one_way(dir_update_directory && dir_update_dir_core == core_index && !dir_update_dir_valid),
				.invalidate_all_ways(1'b0),
				.update_i(dir_update_directory && dir_update_dir_core == core_index && dir_update_dir_valid),
				.update_way_i(dir_update_dir_way),
				.update_tag_i(dir_update_dir_tag),
				.update_set_i(dir_update_dir_set));
		end
	endgenerate

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			tag_l2req_packet <= 0;
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			tag_data_from_memory <= {(1+(`CACHE_LINE_BITS-1)){1'b0}};
			tag_is_restarted_request <= 1'h0;
			tag_miss_fill_l2_way <= 2'h0;
			// End of automatics
		end
		else
		begin
			// restarted command with invalid op
			assert(!(arb_is_restarted_request && (arb_l2req_packet.op == L2REQ_FLUSH 
				|| arb_l2req_packet.op == L2REQ_DINVALIDATE)));

			tag_l2req_packet <= arb_l2req_packet;
			tag_is_restarted_request <= arb_is_restarted_request;
			tag_data_from_memory <= arb_data_from_memory;
			tag_miss_fill_l2_way <= l2_lru_way;
		end
	end
endmodule
