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
// Cache tag memory. This assumes 4 ways, but has a parameterizable number 
// of sets.  This stores both a valid bit for each cache line and the tag
// (the upper bits of the virtual address).  It handles checking for a cache
// hit and updating the tags when data is laoded from memory.
// Since there are four ways, there are also four separate tag RAM blocks, which 
// the address is issued to in parallel. 
//

module l1_cache_tag
	(input 							clk,
	input							reset,
	input[25:0]						request_addr,
	input							access_i,
	output [1:0]					hit_way_o,
	output							cache_hit_o,
	input							update_i,
	input							invalidate_i,
	input[1:0]						update_way_i,
	input[`L1_TAG_WIDTH - 1:0]		update_tag_i,
	input[`L1_SET_INDEX_WIDTH - 1:0] update_set_i);

	wire[`L1_TAG_WIDTH - 1:0]		tag0;
	wire[`L1_TAG_WIDTH - 1:0]		tag1;
	wire[`L1_TAG_WIDTH - 1:0]		tag2;
	wire[`L1_TAG_WIDTH - 1:0]		tag3;
	wire							valid0;
	wire							valid1;
	wire							valid2;
	wire							valid3;
	reg								access_latched;
	reg[`L1_TAG_WIDTH - 1:0]		request_tag_latched;

	wire[`L1_SET_INDEX_WIDTH - 1:0]	requested_set_index = request_addr[`L1_SET_INDEX_WIDTH - 1:0];
	wire[`L1_TAG_WIDTH - 1:0] 		requested_tag = request_addr[25:`L1_SET_INDEX_WIDTH];

	assert_false #("update_i and invalidate_i should not both be asserted") a0(
		.clk(clk), .test(update_i && invalidate_i));

	sram_1r1w #(`L1_TAG_WIDTH + 1, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH) tag_mem0(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data({ valid0, tag0 }),
		.rd_enable(access_i),
		.wr_addr(update_set_i),
		.wr_data({ update_i, update_tag_i }),
		.wr_enable((invalidate_i || update_i) && update_way_i == 0));

	sram_1r1w #(`L1_TAG_WIDTH + 1, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH) tag_mem1(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data({ valid1, tag1 }),
		.rd_enable(access_i),
		.wr_addr(update_set_i),
		.wr_data({ update_i, update_tag_i }),
		.wr_enable((invalidate_i || update_i) && update_way_i == 1));

	sram_1r1w #(`L1_TAG_WIDTH + 1, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH) tag_mem2(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data({ valid2, tag2 }),
		.rd_enable(access_i),
		.wr_addr(update_set_i),
		.wr_data({ update_i, update_tag_i }),
		.wr_enable((invalidate_i || update_i) && update_way_i == 2));

	sram_1r1w #(`L1_TAG_WIDTH + 1, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH) tag_mem3(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data({ valid3, tag3 }),
		.rd_enable(access_i),
		.wr_addr(update_set_i),
		.wr_data({ update_i, update_tag_i }),
		.wr_enable((invalidate_i || update_i) && update_way_i == 3));

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			access_latched <= 1'h0;
			request_tag_latched <= {(1+(`L1_TAG_WIDTH-1)){1'b0}};
			// End of automatics
		end
		else
		begin
			access_latched 		<= access_i;
			request_tag_latched	<= requested_tag;
		end
	end

	wire hit0 = tag0 == request_tag_latched && valid0;
	wire hit1 = tag1 == request_tag_latched && valid1;
	wire hit2 = tag2 == request_tag_latched && valid2;
	wire hit3 = tag3 == request_tag_latched && valid3;

	assign hit_way_o = { hit2 | hit3, hit1 | hit3 };	// convert one-hot to index
	assign cache_hit_o = (hit0 || hit1 || hit2 || hit3) && access_latched;

	assert_false #("more than one way was a hit") a(.clk(clk), 
		.test(access_latched && (hit0 + hit1 + hit2 + hit3 > 1)));
endmodule
