//
// L2 cache tag check stage.
// - Issue address to tag ram (will come out one cycle later)
// - If this is a restarted request, update tag RAM with newly fetched line.
// - Check LRU for requested set
//  

`include "l2_cache.h"

module l2_cache_tag
	(input							clk,
	input							stall_pipeline,
	input							arb_pci_valid,
	input[1:0]						arb_pci_unit,
	input[1:0]						arb_pci_strand,
	input[2:0]						arb_pci_op,
	input[1:0]						arb_pci_way,
	input[25:0]						arb_pci_address,
	input[511:0]					arb_pci_data,
	input[63:0]						arb_pci_mask,
	input							arb_has_sm_data,
	input[511:0]					arb_sm_data,
	input[1:0]						arb_sm_fill_l2_way,
	output reg						tag_pci_valid = 0,
	output reg[1:0]					tag_pci_unit = 0,
	output reg[1:0]					tag_pci_strand = 0,
	output reg[2:0]					tag_pci_op = 0,
	output reg[1:0]					tag_pci_way = 0,
	output reg[25:0]				tag_pci_address = 0,
	output reg[511:0]				tag_pci_data = 0,
	output reg[63:0]				tag_pci_mask = 0,
	output reg						tag_has_sm_data = 0,
	output reg[511:0]				tag_sm_data = 0,
	output reg[1:0]					tag_sm_fill_l2_way = 0,
	output reg[1:0] 				tag_replace_l2_way = 0,
	output [`L2_TAG_WIDTH - 1:0]	tag_l2_tag0,
	output [`L2_TAG_WIDTH - 1:0]	tag_l2_tag1,
	output [`L2_TAG_WIDTH - 1:0]	tag_l2_tag2,
	output [`L2_TAG_WIDTH - 1:0]	tag_l2_tag3,
	output 							tag_l2_valid0,
	output 							tag_l2_valid1,
	output 							tag_l2_valid2,
	output 							tag_l2_valid3);

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = arb_pci_address[`L2_SET_INDEX_WIDTH - 1:0];
	wire[`L2_TAG_WIDTH - 1:0] requested_l2_tag = arb_pci_address[`L2_TAG_WIDTH + `L2_SET_INDEX_WIDTH - 1:`L2_SET_INDEX_WIDTH];
	wire[1:0] l2_lru_way;

	assertion #("restarted command has invalid op") a0(.clk(clk), 
		.test(arb_has_sm_data && (arb_pci_op == `PCI_FLUSH || arb_pci_op == `PCI_INVALIDATE)));

	cache_lru #(`L2_NUM_SETS, `L2_SET_INDEX_WIDTH) lru(
		.clk(clk),
		.new_mru_way(tag_sm_fill_l2_way),
		.set_i(tag_has_sm_data ? tag_sm_fill_l2_way : requested_l2_set),
		.update_mru(tag_pci_valid),
		.lru_way_o(l2_lru_way));

	wire update_way0 = !stall_pipeline && arb_has_sm_data && arb_sm_fill_l2_way == 0;
	wire update_way1 = !stall_pipeline && arb_has_sm_data && arb_sm_fill_l2_way == 1;
	wire update_way2 = !stall_pipeline && arb_has_sm_data && arb_sm_fill_l2_way == 2;
	wire update_way3 = !stall_pipeline && arb_has_sm_data && arb_sm_fill_l2_way == 3;

	sram_1r1w #(`L2_TAG_WIDTH, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_tag_mem0(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_tag0),
		.wr_addr(requested_l2_set),
		.wr_data(requested_l2_tag),
		.wr_enable(update_way0));

	sram_1r1w #(`L2_TAG_WIDTH, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_tag_mem1(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_tag1),
		.wr_addr(requested_l2_set),
		.wr_data(requested_l2_tag),
		.wr_enable(update_way1));

	sram_1r1w #(`L2_TAG_WIDTH, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_tag_mem2(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_tag2),
		.wr_addr(requested_l2_set),
		.wr_data(requested_l2_tag),
		.wr_enable(update_way2));

	sram_1r1w #(`L2_TAG_WIDTH, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_tag_mem3(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_tag3),
		.wr_addr(requested_l2_set),
		.wr_data(requested_l2_tag),
		.wr_enable(update_way3));
	
	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_valid_mem0(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_valid0),
		.wr_addr(requested_l2_set),
		.wr_data(1'b1),
		.wr_enable(update_way0));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_valid_mem1(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_valid1),
		.wr_addr(requested_l2_set),
		.wr_data(1'b1),
		.wr_enable(update_way1));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_valid_mem2(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_valid2),
		.wr_addr(requested_l2_set),
		.wr_data(1'b1),
		.wr_enable(update_way2));

	sram_1r1w #(1, `L2_NUM_SETS, `L2_SET_INDEX_WIDTH, 1) l2_valid_mem3(
		.clk(clk),
		.rd_addr(requested_l2_set),
		.rd_data(tag_l2_valid3),
		.wr_addr(requested_l2_set),
		.wr_data(1'b1),
		.wr_enable(update_way3));

	always @(posedge clk)
	begin
		if (!stall_pipeline)
		begin
			tag_pci_valid <= #1 arb_pci_valid;
			tag_pci_unit <= #1 arb_pci_unit;
			tag_pci_strand <= #1 arb_pci_strand;
			tag_pci_op <= #1 arb_pci_op;
			tag_pci_way <= #1 arb_pci_way;
			tag_pci_address <= #1 arb_pci_address;
			tag_pci_data <= #1 arb_pci_data;
			tag_pci_mask <= #1 arb_pci_mask;
			tag_has_sm_data <= #1 arb_has_sm_data;	
			tag_sm_data <= #1 arb_sm_data;
			tag_replace_l2_way <= #1 l2_lru_way;
			tag_sm_fill_l2_way <= #1 arb_sm_fill_l2_way;
		end
	end
endmodule
