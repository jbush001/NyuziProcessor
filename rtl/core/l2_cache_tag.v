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
// - Issue address to tag ram (will come out one cycle later)
// - If this is a restarted request, update tag RAM with newly fetched line.
// - Check LRU for requested set
//  

module l2_cache_tag
	(input							clk,
	input							reset,
	input							stall_pipeline,
	input							arb_l2req_valid,
	input[1:0]						arb_l2req_unit,
	input[1:0]						arb_l2req_strand,
	input[2:0]						arb_l2req_op,
	input[1:0]						arb_l2req_way,
	input[25:0]						arb_l2req_address,
	input[511:0]					arb_l2req_data,
	input[63:0]						arb_l2req_mask,
	input							arb_has_sm_data,
	input[511:0]					arb_sm_data,
	input[1:0]						arb_sm_fill_l2_way,
	output reg						tag_l2req_valid,
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
	input							dir_update_tag_enable,
	input [`L2_TAG_WIDTH - 1:0] 	dir_update_tag_tag,
	input [`L2_SET_INDEX_WIDTH - 1:0] dir_update_tag_set,
	input [1:0] 					dir_update_tag_way);

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = arb_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];
	wire[`L2_TAG_WIDTH - 1:0] requested_l2_tag = arb_l2req_address[`L2_TAG_WIDTH + `L2_SET_INDEX_WIDTH - 1:`L2_SET_INDEX_WIDTH];
	wire[1:0] l2_lru_way;

	assert_false #("restarted command has invalid op") a0(.clk(clk), 
		.test(arb_has_sm_data && (arb_l2req_op == `L2REQ_FLUSH || arb_l2req_op == `L2REQ_INVALIDATE)));

	cache_lru #(`L2_NUM_SETS, `L2_SET_INDEX_WIDTH) lru(
		.access_i(arb_l2req_valid),
		.new_mru_way(tag_sm_fill_l2_way),
		.set_i(tag_has_sm_data ? tag_sm_fill_l2_way : requested_l2_set),
		.update_mru(tag_l2req_valid),
		.lru_way_o(l2_lru_way),
		/*AUTOINST*/
							   // Inputs
							   .clk			(clk),
							   .reset		(reset));

	wire update_way0 = dir_update_tag_enable && dir_update_tag_way == 0;
	wire update_way1 = dir_update_tag_enable && dir_update_tag_way == 1;
	wire update_way2 = dir_update_tag_enable && dir_update_tag_way == 2;
	wire update_way3 = dir_update_tag_enable && dir_update_tag_way == 3;

	sram_1r1w #(`L2_TAG_WIDTH + 1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 0) l2_tag_mem0(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data({ tag_l2_valid0, tag_l2_tag0 }),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_tag_set),
		.wr_data({ 1'b1, dir_update_tag_tag }),
		.wr_enable(update_way0));

	sram_1r1w #(`L2_TAG_WIDTH + 1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 0) l2_tag_mem1(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data({ tag_l2_valid1, tag_l2_tag1 }),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_tag_set),
		.wr_data({ 1'b1, dir_update_tag_tag }),
		.wr_enable(update_way1));

	sram_1r1w #(`L2_TAG_WIDTH + 1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 0) l2_tag_mem2(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data({ tag_l2_valid2, tag_l2_tag2 }),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_tag_set),
		.wr_data({ 1'b1, dir_update_tag_tag }),
		.wr_enable(update_way2));

	sram_1r1w #(`L2_TAG_WIDTH + 1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 0) l2_tag_mem3(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data({ tag_l2_valid3, tag_l2_tag3 }),
		.rd_enable(arb_l2req_valid),
		.wr_addr(dir_update_tag_set),
		.wr_data({ 1'b1, dir_update_tag_tag }),
		.wr_enable(update_way3));

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			tag_has_sm_data <= 1'h0;
			tag_l2req_address <= 26'h0;
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
