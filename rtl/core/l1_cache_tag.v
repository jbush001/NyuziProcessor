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
// Cache tag memory. This assumes 4 ways, but has a parameterizable number 
// of sets.  This stores both a valid bit for each cache line and the tag
// (the upper bits of the virtual address).  It handles checking for a cache
// hit and updating the tags when data is laoded from memory.
// Since there are four ways, there are also four separate tag RAM blocks, which 
// the address is issued to in parallel. 
// Tag memory has one cycle of latency. cache_hit_o and hit_way_o will be valid
// in the next cycle after request_addr is asserted.
//

module l1_cache_tag
	(input 							clk,
	input							reset,
	
	// Request
	input[25:0]						request_addr,
	input							access_i,
	
	// Response	
	output [1:0]					hit_way_o,
	output							cache_hit_o,

	// Update (from L2 cache)
	input							update_i,
	input							invalidate_one_way,
	input							invalidate_all_ways,
	input[1:0]						update_way_i,
	input[`L1_TAG_WIDTH - 1:0]		update_tag_i,
	input[`L1_SET_INDEX_WIDTH - 1:0] update_set_i);

	wire[`L1_TAG_WIDTH * `L1_NUM_WAYS - 1:0] tag;
	wire[`L1_NUM_WAYS - 1:0] valid;
	reg access_latched;
	reg[`L1_TAG_WIDTH - 1:0] request_tag_latched;
	wire[`L1_NUM_WAYS - 1:0] update_way;

	wire[`L1_SET_INDEX_WIDTH - 1:0] requested_set_index = request_addr[`L1_SET_INDEX_WIDTH - 1:0];
	wire[`L1_TAG_WIDTH - 1:0] requested_tag = request_addr[25:`L1_SET_INDEX_WIDTH];

	cache_valid_array #(.NUM_SETS(`L1_NUM_SETS)) valid_mem[`L1_NUM_WAYS - 1:0] (
		.clk(clk),
		.reset(reset),
		.rd_enable(access_i),
		.rd_addr(requested_set_index),
		.rd_is_valid(valid),
		.wr_addr(update_set_i),
		.wr_is_valid(update_i),
		.wr_enable(update_way));

	sram_1r1w #(.DATA_WIDTH(`L1_TAG_WIDTH), .SIZE(`L1_NUM_SETS)) tag_mem[`L1_NUM_WAYS - 1:0] (
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data(tag),
		.rd_enable(access_i),
		.wr_addr(update_set_i),
		.wr_data(update_tag_i),
		.wr_enable(update_way));
		
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

	wire [`L1_NUM_WAYS - 1:0] hit_way_oh;
	genvar way;
	generate
		for (way = 0; way < `L1_NUM_WAYS; way = way + 1)
		begin : makeway
			assign hit_way_oh[way] = tag[way * `L1_TAG_WIDTH+:`L1_TAG_WIDTH] ==
				request_tag_latched && valid[way];
			assign update_way[way] = ((invalidate_one_way || update_i) 
				&& update_way_i == way) || invalidate_all_ways;
		end
	endgenerate

	one_hot_to_index #(.NUM_SIGNALS(`L1_NUM_WAYS)) cvt_hit_way(
		.one_hot(hit_way_oh),
		.index(hit_way_o));

	assign cache_hit_o = |hit_way_oh && access_latched;

`ifdef SIMULATION
	assert_false #("update_i and invalidate_one_way should not both be asserted") a0(
		.clk(clk), .test(update_i && invalidate_one_way));
	assert_false #("more than one way was a hit") a(.clk(clk), 
		.test(access_latched && ((hit_way_oh & (hit_way_oh - 1)) != 0)));
`endif

endmodule
