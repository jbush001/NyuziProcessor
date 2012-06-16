//
// L2 cache pipeline data read stage.
// This stage issues reads for cached data.  Since cache memory has one cycle of latency,
// the result will appear in the next pipeline stage.
//
//  - Track synchronized loads/stores
//  - Issue read data from L2 cache line 
//     Cache hit: requested line
//     Cache miss, dirty line: line that will be written back
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
	input[1:0] 					dir_hit_l2_way,
	input[1:0] 					dir_replace_l2_way,
	input 						dir_cache_hit,
	input[`L2_TAG_WIDTH - 1:0] 	dir_replace_l2_tag,
	input						dir_l1_has_line,
	input[`NUM_CORES * 2 - 1:0] dir_l1_way,
	input 						dir_l2_dirty0,	// Note: these imply that the dirty line is also valid
	input 						dir_l2_dirty1,
	input 						dir_l2_dirty2,
	input 						dir_l2_dirty3,
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
	output reg[1:0]				rd_sm_fill_l2_way = 0,
	output reg[1:0] 			rd_hit_l2_way = 0,
	output reg[1:0] 			rd_replace_l2_way = 0,
	output reg 					rd_cache_hit = 0,
	output reg[`NUM_CORES - 1:0] rd_l1_has_line = 0,
	output reg[`NUM_CORES * 2 - 1:0] rd_dir_l1_way = 0,
	output [511:0] 				rd_cache_mem_result,
	output reg[`L2_TAG_WIDTH - 1:0] rd_replace_l2_tag = 0,
	output reg 					rd_replace_is_dirty = 0,
	output reg                  rd_store_sync_success = 0);

	localparam TOTAL_STRANDS = `NUM_CORES * `STRANDS_PER_CORE;

	reg[25:0] sync_load_address[0:TOTAL_STRANDS - 1]; 
	reg sync_load_address_valid[0:TOTAL_STRANDS - 1];
	integer i;

	initial
	begin
		for (i = 0; i < TOTAL_STRANDS; i = i + 1)
		begin
			sync_load_address[i] = 26'h3ffffff;	
			sync_load_address_valid[i] = 0;
		end
	end

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = dir_pci_address[`L2_SET_INDEX_WIDTH - 1:0];

	// Actual line to read
	wire[`L2_CACHE_ADDR_WIDTH - 1:0] cache_read_index = dir_cache_hit
		? { dir_hit_l2_way, requested_l2_set }
		: { dir_sm_fill_way, requested_l2_set }; // Get data from a (potentially) dirty line that is about to be replaced.

	sram_1r1w #(512, `L2_NUM_SETS * `L2_NUM_WAYS, `L2_CACHE_ADDR_WIDTH, 1) cache_mem(
		.clk(clk),
		.rd_addr(cache_read_index),
		.rd_data(rd_cache_mem_result),
		.wr_addr(wr_cache_write_index),
		.wr_data(wr_update_data),
		.wr_enable(wr_update_l2_data));

	reg replace_is_dirty_muxed = 0;
	always @*
	begin
		case (dir_sm_fill_way)
			0: replace_is_dirty_muxed = dir_l2_dirty0;
			1: replace_is_dirty_muxed = dir_l2_dirty1;
			2: replace_is_dirty_muxed = dir_l2_dirty2;
			3: replace_is_dirty_muxed = dir_l2_dirty3;
		endcase
	end
	
	// Synchronize loads/store handling
	integer k;
	always @(posedge clk)
	begin
		case (dir_pci_op)
			`PCI_LOAD_SYNC:
			begin
				sync_load_address[dir_pci_strand] <= #1 dir_pci_address;
				sync_load_address_valid[dir_pci_strand] <= #1 1;
			end

			`PCI_STORE,
			`PCI_STORE_SYNC:
			begin
				// Invalidate
				for (k = 0; k < TOTAL_STRANDS; k = k + 1)
				begin
					if (sync_load_address[k] == dir_pci_address)
						sync_load_address_valid[k] <= #1 0;
				end
			end
		endcase

		rd_store_sync_success <= #1 sync_load_address[dir_pci_strand] == dir_pci_address
			&& sync_load_address_valid[dir_pci_strand];
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
			rd_hit_l2_way <= #1 dir_hit_l2_way;
			rd_replace_l2_way <= #1 dir_replace_l2_way;
			rd_cache_hit <= #1 dir_cache_hit;
			rd_l1_has_line <= #1 dir_l1_has_line;
			rd_dir_l1_way <= #1 dir_l1_way;
			rd_replace_l2_tag <= #1 dir_replace_l2_tag;
			rd_replace_is_dirty <= #1 replace_is_dirty_muxed;
			rd_sm_fill_l2_way <= #1 dir_sm_fill_way;
		end
	end	
endmodule