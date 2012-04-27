//
// Directory Check, Cache memory read issue	
//  - Check/Update dirty bits
//  - Cache hit: read data from L2 cache line
//  - Cache miss, dirty line: read line to write back
//

`include "l2_cache.h"

module l2_cache_read(
	input						clk,
	input						stall_pipeline,
	input						dir_pci_valid,
	input[1:0]					dir_pci_unit,
	input[1:0]					dir_pci_strand,
	input[2:0]					dir_pci_op,
	input[1:0]					dir_pci_way,
	input[25:0]					dir_pci_address,
	input[511:0]				dir_pci_data,
	input[63:0]					dir_pci_mask,
	input						dir_has_sm_data,
	input[511:0]				dir_sm_data,
	input[1:0] 					dir_hit_way,
	input[1:0] 					dir_replace_way,
	input 						dir_cache_hit,
	input[`L2_TAG_WIDTH - 1:0] 	dir_replace_tag,
	input[`NUM_CORES - 1:0] 	dir_l1_valid,
	input[`NUM_CORES * 2 - 1:0] dir_l1_way,
	input[`NUM_CORES * `L1_TAG_WIDTH - 1:0] dir_l1_tag,
	input 						dir_dirty0,
	input 						dir_dirty1,
	input 						dir_dirty2,
	input 						dir_dirty3,
	input [1:0]					dir_sm_fill_way,
	input 						wr_update_l2_data,
	input [`L2_CACHE_ADDR_WIDTH -1:0] wr_cache_write_index,
	input[511:0] 				wr_update_data,

	output reg					rd_pci_valid = 0,
	output reg[1:0]				rd_pci_unit = 0,
	output reg[1:0]				rd_pci_strand = 0,
	output reg[2:0]				rd_pci_op = 0,
	output reg[1:0]				rd_pci_way = 0,
	output reg[25:0]			rd_pci_address = 0,
	output reg[511:0]			rd_pci_data = 0,
	output reg[63:0]			rd_pci_mask = 0,
	output reg 					rd_has_sm_data = 0,
	output reg[511:0] 			rd_sm_data = 0,
	output reg[1:0]				rd_sm_fill_way = 0,
	output reg[1:0] 			rd_hit_way = 0,
	output reg[1:0] 			rd_replace_way = 0,
	output reg 					rd_cache_hit = 0,
	output reg[`NUM_CORES - 1:0] rd_dir_valid = 0,
	output reg[`NUM_CORES * 2 - 1:0] rd_dir_way = 0,
	output reg[`NUM_CORES * `L1_TAG_WIDTH - 1:0] rd_dir_tag = 0,
	output reg[`L2_SET_INDEX_WIDTH - 1:0] rd_request_set = 0,
	output [511:0] 				rd_cache_mem_result,
	output reg[`L2_TAG_WIDTH - 1:0] rd_replace_tag = 0,
	output reg 					rd_replace_is_dirty = 0);

	// Memories
	reg[511:0] cache_mem[0:`L2_NUM_SETS * `L2_NUM_WAYS - 1];	

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_set_index = dir_pci_address[6 + `L2_SET_INDEX_WIDTH - 1:6];

	// Actual line to read
	wire[`L2_CACHE_ADDR_WIDTH - 1:0] cache_read_index = dir_cache_hit
		? { dir_hit_way, requested_set_index }
		: { dir_replace_way, requested_set_index }; // Get data from a (potentially) dirty line that is about to be replaced.
	reg[`L2_CACHE_ADDR_WIDTH - 1:0] cache_read_index_latched = 0;

	reg replace_is_dirty_muxed = 0;
	always @*
	begin
		case (dir_replace_way)
			0: replace_is_dirty_muxed = dir_dirty0;
			1: replace_is_dirty_muxed = dir_dirty1;
			2: replace_is_dirty_muxed = dir_dirty2;
			3: replace_is_dirty_muxed = dir_dirty3;
		endcase
	end

	always @(posedge clk)
	begin
		if (!stall_pipeline)
		begin
			rd_pci_valid <= #1 dir_pci_valid;
			rd_pci_unit <= #1 dir_pci_unit;
			rd_pci_strand <= #1 dir_pci_strand;
			rd_pci_op <= #1 dir_pci_op;
			rd_pci_way <= #1 dir_pci_way;
			rd_pci_address <= #1 dir_pci_address;
			rd_pci_data <= #1 dir_pci_data;
			rd_pci_mask <= #1 dir_pci_mask;
			rd_has_sm_data <= #1 dir_has_sm_data;	
			rd_sm_data <= #1 dir_sm_data;	
			rd_hit_way <= #1 dir_hit_way;
			rd_replace_way <= #1 dir_replace_way;
			rd_cache_hit <= #1 dir_cache_hit;
			rd_dir_valid <= #1 dir_l1_valid;
			rd_dir_way <= #1 dir_l1_way;
			rd_dir_tag <= #1 dir_l1_tag;
			rd_replace_tag <= #1 dir_replace_tag;
			rd_replace_is_dirty <= #1 replace_is_dirty_muxed;
			rd_sm_fill_way <= #1 dir_sm_fill_way;
			cache_read_index_latched <= #1 cache_read_index;
			if (wr_update_l2_data)
				cache_mem[wr_cache_write_index] <= #1 wr_update_data;
		end
	end	

	assign rd_cache_mem_result = cache_mem[cache_read_index_latched];
endmodule