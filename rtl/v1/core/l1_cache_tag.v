// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
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
	(input                             clk,
	input                              reset,
	
	// Request
	input[25:0]                        request_addr,
	input                              access_i,
	
	// Response	
	output [1:0]                       hit_way_o,
	output                             cache_hit_o,

	// Update (from L2 cache)
	input                              update_i,
	input                              invalidate_one_way,
	input                              invalidate_all_ways,
	input[1:0]                         update_way_i,
	input[`L1_TAG_WIDTH - 1:0]         update_tag_i,
	input[`L1_SET_INDEX_WIDTH - 1:0]   update_set_i);

	logic[`L1_TAG_WIDTH * 4 - 1:0] tag;
	logic[`L1_NUM_WAYS - 1:0] valid;
	logic access_latched;
	logic[`L1_TAG_WIDTH - 1:0] request_tag_latched;
	logic[`L1_NUM_WAYS - 1:0] update_way;

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
		
	always_ff @(posedge clk, posedge reset)
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
			// update_i and invalidate_one_way should not both be asserted
			assert(!(update_i && invalidate_one_way));

			// Make sure more than one way isn't a hit
			assert($onehot0(hit_way_oh) || !access_latched);

			access_latched <= access_i;
			request_tag_latched <= requested_tag;
		end
	end

	logic [`L1_NUM_WAYS - 1:0] hit_way_oh;
	genvar way;
	generate
		for (way = 0; way < `L1_NUM_WAYS; way++)
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

endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

