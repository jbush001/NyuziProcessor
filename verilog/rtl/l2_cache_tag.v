//
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
	input[1:0]						arb_sm_fill_way,
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
	output reg[1:0]					tag_sm_fill_way = 0,
	output reg[1:0] 				tag_replace_way = 0,
	output reg[`L2_TAG_WIDTH - 1:0]	tag_tag0 = 0,
	output reg[`L2_TAG_WIDTH - 1:0]	tag_tag1 = 0,
	output reg[`L2_TAG_WIDTH - 1:0]	tag_tag2 = 0,
	output reg[`L2_TAG_WIDTH - 1:0]	tag_tag3 = 0,
	output reg						tag_valid0 = 0,
	output reg						tag_valid1 = 0,
	output reg						tag_valid2 = 0,
	output reg						tag_valid3 = 0);

	integer i;

	// Memories
	reg[`L2_TAG_WIDTH - 1:0]	tag_mem0[0:`L2_NUM_SETS - 1];
	reg						valid_mem0[0:`L2_NUM_SETS - 1];
	reg[`L2_TAG_WIDTH - 1:0]	tag_mem1[0:`L2_NUM_SETS - 1];
	reg						valid_mem1[0:`L2_NUM_SETS - 1];
	reg[`L2_TAG_WIDTH - 1:0]	tag_mem2[0:`L2_NUM_SETS - 1];
	reg						valid_mem2[0:`L2_NUM_SETS - 1];
	reg[`L2_TAG_WIDTH - 1:0]	tag_mem3[0:`L2_NUM_SETS - 1];
	reg						valid_mem3[0:`L2_NUM_SETS - 1];

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_set_index = arb_pci_address[`L2_SET_INDEX_WIDTH - 1:0];
	wire[`L2_TAG_WIDTH - 1:0] requested_tag = arb_pci_address[`L2_TAG_WIDTH + `L2_SET_INDEX_WIDTH - 1:`L2_SET_INDEX_WIDTH];
	wire[1:0] lru_way;

	initial
	begin
		for (i = 0; i < `L2_NUM_SETS; i = i + 1)
		begin
			tag_mem0[i] = 0;
			tag_mem1[i] = 0;
			tag_mem2[i] = 0;
			tag_mem3[i] = 0;
			valid_mem0[i] = 0;
			valid_mem1[i] = 0;
			valid_mem2[i] = 0;
			valid_mem3[i] = 0;
		end	
	end

	cache_lru #(`L2_NUM_SETS, `L2_SET_INDEX_WIDTH) lru(
		.clk(clk),
		.new_mru_way(tag_sm_fill_way),
		.set_i(tag_has_sm_data ? tag_sm_fill_way : requested_set_index),
		.update_mru(tag_pci_valid),
		.lru_way_o(lru_way));

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
			tag_replace_way <= #1 lru_way;
			tag_tag0 	<= #1 tag_mem0[requested_set_index];
			tag_valid0 <= #1 valid_mem0[requested_set_index];
			tag_tag1 	<= #1 tag_mem1[requested_set_index];
			tag_valid1 <= #1 valid_mem1[requested_set_index];
			tag_tag2 	<= #1 tag_mem2[requested_set_index];
			tag_valid2 <= #1 valid_mem2[requested_set_index];
			tag_tag3 	<= #1 tag_mem3[requested_set_index];
			tag_valid3 <= #1 valid_mem3[requested_set_index];
			tag_sm_fill_way <= #1 arb_sm_fill_way;
			if (arb_has_sm_data)
			begin
				// Update tag memory if this is a restarted request
				case (arb_sm_fill_way)
					0:
					begin
						valid_mem0[requested_set_index] <= #1 1;
						tag_mem0[requested_set_index] <= #1 requested_tag;
					end

					1:
					begin
						valid_mem1[requested_set_index] <= #1 1;
						tag_mem1[requested_set_index] <= #1 requested_tag;
					end

					2:
					begin
						valid_mem2[requested_set_index] <= #1 1;
						tag_mem2[requested_set_index] <= #1 requested_tag;
					end

					3:				
					begin
						valid_mem3[requested_set_index] <= #1 1;
						tag_mem3[requested_set_index] <= #1 requested_tag;
					end
				endcase
			end
		end
	end

endmodule
