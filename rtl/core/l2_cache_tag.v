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
	(input							clk,
	input							reset,
	input							stall_pipeline,
	input							arb_l2req_valid,
	input [3:0]						arb_l2req_core,
	input [1:0]						arb_l2req_unit,
	input [1:0]						arb_l2req_strand,
	input [2:0]						arb_l2req_op,
	input [1:0]						arb_l2req_way,
	input [25:0]					arb_l2req_address,
	input [511:0]					arb_l2req_data,
	input [63:0]					arb_l2req_mask,
	input							arb_has_sm_data,
	input [511:0]					arb_sm_data,
	input [1:0]						arb_sm_fill_l2_way,
	output reg						tag_l2req_valid,
	output reg[3:0]					tag_l2req_core,
	output reg[1:0]					tag_l2req_unit,
	output reg[1:0]					tag_l2req_strand,
	output reg[2:0]					tag_l2req_op,
	output reg[1:0]					tag_l2req_way,
	output reg[25:0]				tag_l2req_address,
	output reg[511:0]				tag_l2req_data,
	output reg[63:0]				tag_l2req_mask,
	output reg						tag_has_sm_data,
	output reg[511:0]				tag_sm_data,
	output reg[1:0]					tag_sm_fill_l2_way,
	output reg[1:0] 				tag_replace_l2_way,
	output [`L2_TAG_WIDTH - 1:0]	tag_l2_tag0,
	output [`L2_TAG_WIDTH - 1:0]	tag_l2_tag1,
	output [`L2_TAG_WIDTH - 1:0]	tag_l2_tag2,
	output [`L2_TAG_WIDTH - 1:0]	tag_l2_tag3,
	output 							tag_l2_valid0,
	output 							tag_l2_valid1,
	output 							tag_l2_valid2,
	output 							tag_l2_valid3,
	output							tag_l2_dirty0,
	output							tag_l2_dirty1,
	output							tag_l2_dirty2,
	output							tag_l2_dirty3,
	output                          tag_l1_has_line,
	output [`NUM_CORES * 2 - 1:0]   tag_l1_way,
	input							dir_update_tag_enable,
	input							dir_update_tag_valid,
	input [`L2_TAG_WIDTH - 1:0] 	dir_update_tag_tag,
	input [`L2_SET_INDEX_WIDTH - 1:0] dir_update_tag_set,
	input [1:0] 					dir_update_tag_way,
	input [`L2_SET_INDEX_WIDTH - 1:0] dir_update_dirty_set,
	input							dir_new_dirty,
	input							dir_update_dirty0,
	input							dir_update_dirty1,
	input							dir_update_dirty2,
	input							dir_update_dirty3,
	input							dir_update_directory0,
	input							dir_update_dir_valid, 
	input [1:0]						dir_update_dir_way,
	input [`L1_TAG_WIDTH - 1:0]		dir_update_dir_tag, 
	input [`L1_SET_INDEX_WIDTH - 1:0] dir_update_dir_set);

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = arb_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];
	wire[1:0] l2_lru_way;

	assert_false #("restarted command has invalid op") a0(.clk(clk), 
		.test(arb_has_sm_data && (arb_l2req_op == `L2REQ_FLUSH || arb_l2req_op == `L2REQ_INVALIDATE)));

	cache_lru #(`L2_NUM_SETS, `L2_SET_INDEX_WIDTH) lru(
		.clk(clk),
		.reset(reset),
		.access_i(arb_l2req_valid),
		.new_mru_way(tag_sm_fill_l2_way),
		.set_i(tag_has_sm_data ? tag_sm_fill_l2_way : requested_l2_set),
		.update_mru(tag_l2req_valid),
		.lru_way_o(l2_lru_way));

	wire update_tag_way0 = dir_update_tag_enable && dir_update_tag_way == 0;
	wire update_tag_way1 = dir_update_tag_enable && dir_update_tag_way == 1;
	wire update_tag_way2 = dir_update_tag_enable && dir_update_tag_way == 2;
	wire update_tag_way3 = dir_update_tag_enable && dir_update_tag_way == 3;

	sram_1r1w #(`L2_TAG_WIDTH + 1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH) l2_tag_mem0(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data({ tag_l2_valid0, tag_l2_tag0 }),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_tag_set),
		.wr_data({ dir_update_tag_valid, dir_update_tag_tag }),
		.wr_enable(update_tag_way0));

	sram_1r1w #(`L2_TAG_WIDTH + 1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH) l2_tag_mem1(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data({ tag_l2_valid1, tag_l2_tag1 }),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_tag_set),
		.wr_data({ dir_update_tag_valid, dir_update_tag_tag }),
		.wr_enable(update_tag_way1));

	sram_1r1w #(`L2_TAG_WIDTH + 1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH) l2_tag_mem2(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data({ tag_l2_valid2, tag_l2_tag2 }),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_tag_set),
		.wr_data({ dir_update_tag_valid, dir_update_tag_tag }),
		.wr_enable(update_tag_way2));

	sram_1r1w #(`L2_TAG_WIDTH + 1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH) l2_tag_mem3(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data({ tag_l2_valid3, tag_l2_tag3 }),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_tag_set),
		.wr_data({ dir_update_tag_valid, dir_update_tag_tag }),
		.wr_enable(update_tag_way3));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH) l2_dirty_mem0(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_dirty0),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_dirty_set),
		.wr_data(dir_new_dirty),
		.wr_enable(dir_update_dirty0));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH) l2_dirty_mem1(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_dirty1),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_dirty_set),
		.wr_data(dir_new_dirty),
		.wr_enable(dir_update_dirty1));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH) l2_dirty_mem2(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_dirty2),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_dirty_set),
		.wr_data(dir_new_dirty),
		.wr_enable(dir_update_dirty2));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH) l2_dirty_mem3(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_dirty3),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_dirty_set),
		.wr_data(dir_new_dirty),
		.wr_enable(dir_update_dirty3));

	// The directory is basically a clone of the tag memories for all core's L1 data
	// caches.
	l1_cache_tag directory0(
		.clk(clk),
		.reset(reset),
		.request_addr(arb_l2req_address),
		.access_i(arb_l2req_valid && arb_l2req_core == 4'd0),	// XXX && not fill?
		.cache_hit_o(tag_l1_has_line),
		.hit_way_o(tag_l1_way),
		.invalidate_i(dir_update_directory0 && !dir_update_dir_valid),
		.update_i(dir_update_directory0 && dir_update_dir_valid),
		.update_way_i(dir_update_dir_way),
		.update_tag_i(dir_update_dir_tag),
		.update_set_i(dir_update_dir_set));

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			tag_has_sm_data <= 1'h0;
			tag_l2req_address <= 26'h0;
			tag_l2req_core <= 4'h0;
			tag_l2req_data <= 512'h0;
			tag_l2req_mask <= 64'h0;
			tag_l2req_op <= 3'h0;
			tag_l2req_strand <= 2'h0;
			tag_l2req_unit <= 2'h0;
			tag_l2req_valid <= 1'h0;
			tag_l2req_way <= 2'h0;
			tag_replace_l2_way <= 2'h0;
			tag_sm_data <= 512'h0;
			tag_sm_fill_l2_way <= 2'h0;
			// End of automatics
		end
		else if (!stall_pipeline)
		begin
			tag_l2req_valid <= arb_l2req_valid;
			tag_l2req_core <= arb_l2req_core;
			tag_l2req_unit <= arb_l2req_unit;
			tag_l2req_strand <= arb_l2req_strand;
			tag_l2req_op <= arb_l2req_op;
			tag_l2req_way <= arb_l2req_way;
			tag_l2req_address <= arb_l2req_address;
			tag_l2req_data <= arb_l2req_data;
			tag_l2req_mask <= arb_l2req_mask;
			tag_has_sm_data <= arb_has_sm_data;	
			tag_sm_data <= arb_sm_data;
			tag_replace_l2_way <= l2_lru_way;
			tag_sm_fill_l2_way <= arb_sm_fill_l2_way;
		end
	end
endmodule
