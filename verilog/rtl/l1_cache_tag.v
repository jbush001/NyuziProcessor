//
// Cache tag memory. This assumes 4 ways, but has a parameterizable number 
// of sets.  This stores both a valid bit for each cache line and the tag
// (the upper bits of the virtual address).  It handles checking for a cache
// hit and updating the tags when data is laoded from memory.
// Since there are four ways, there are also four separate tag RAM blocks, which 
// the address is issued to in parallel. 
//

`include "l2_cache.h"

module l1_cache_tag
	(input 							clk,
	input[31:0]						address_i,
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
	reg								access_latched = 0;
	reg[`L1_TAG_WIDTH - 1:0]		request_tag_latched = 0;

	wire[`L1_SET_INDEX_WIDTH - 1:0]	requested_set_index = address_i[10:6];
	wire[`L1_TAG_WIDTH - 1:0] 		requested_tag = address_i[31:11];

	sram_1r1w #(`L1_TAG_WIDTH, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) tag_mem0(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data(tag0),
		.wr_addr(update_set_i),
		.wr_data(update_tag_i),
		.wr_enable(update_i && update_way_i == 0));

	sram_1r1w #(`L1_TAG_WIDTH, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) tag_mem1(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data(tag1),
		.wr_addr(update_set_i),
		.wr_data(update_tag_i),
		.wr_enable(update_i && update_way_i == 1));

	sram_1r1w #(`L1_TAG_WIDTH, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) tag_mem2(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data(tag2),
		.wr_addr(update_set_i),
		.wr_data(update_tag_i),
		.wr_enable(update_i && update_way_i == 2));

	sram_1r1w #(`L1_TAG_WIDTH, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) tag_mem3(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data(tag3),
		.wr_addr(update_set_i),
		.wr_data(update_tag_i),
		.wr_enable(update_i && update_way_i == 3));

	sram_1r1w #(1, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) valid_mem0(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data(valid0),
		.wr_addr(update_set_i),
		.wr_data(update_i),
		.wr_enable((invalidate_i || update_i) && update_way_i == 0));

	sram_1r1w #(1, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) valid_mem1(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data(valid1),
		.wr_addr(update_set_i),
		.wr_data(update_i),
		.wr_enable((invalidate_i || update_i) && update_way_i == 1));

	sram_1r1w #(1, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) valid_mem2(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data(valid2),
		.wr_addr(update_set_i),
		.wr_data(update_i),
		.wr_enable((invalidate_i || update_i) && update_way_i == 2));

	sram_1r1w #(1, `L1_NUM_SETS, `L1_SET_INDEX_WIDTH, 1) valid_mem3(
		.clk(clk),
		.rd_addr(requested_set_index),
		.rd_data(valid3),
		.wr_addr(update_set_i),
		.wr_data(update_i),
		.wr_enable((invalidate_i || update_i) && update_way_i == 3));

	always @(posedge clk)
	begin
		access_latched 		<= #1 access_i;
		request_tag_latched	<= #1 requested_tag;
	end

	wire hit0 = tag0 == request_tag_latched && valid0;
	wire hit1 = tag1 == request_tag_latched && valid1;
	wire hit2 = tag2 == request_tag_latched && valid2;
	wire hit3 = tag3 == request_tag_latched && valid3;

	assign hit_way_o = { hit2 | hit3, hit1 | hit3 };	// convert one-hot to index
	assign cache_hit_o = (hit0 || hit1 || hit2 || hit3) && access_latched;

	assertion #("l1_cache_tag: more than one way was a hit") a(.clk(clk), 
		.test(access_latched && (hit0 + hit1 + hit2 + hit3 > 1)));
endmodule
