//
// Stage 4: Cache memory write issue
// This is where most of the magic happens
// - For writes, combine the requested write data with the
//   previous data in the line.  Otherwise just pass data 
//   through.
//

`include "l2_cache.h"

module l2_cache_write(
	input clk,
	input stall_pipeline,
	input 			rd_pci_valid,
	input [1:0]	rd_pci_unit,
	input [1:0]	rd_pci_strand,
	input [2:0]	rd_pci_op,
	input [1:0]	rd_pci_way,
	input [25:0]	rd_pci_address,
	input [511:0]	rd_pci_data,
	input [63:0]	rd_pci_mask,
	input  		rd_has_sm_data,
	input [511:0] 	rd_sm_data,
	input [1:0] 	rd_hit_way,
	input [1:0] 	rd_replace_way,
	input  		rd_cache_hit,
	input [`NUM_CORES - 1:0] rd_dir_valid,
	input [`NUM_CORES * 2 - 1:0] rd_dir_way,
	input [`NUM_CORES * `L1_TAG_WIDTH - 1:0] rd_dir_tag,
	input [`L2_SET_INDEX_WIDTH - 1:0] rd_request_set,
	input [`L2_CACHE_ADDR_WIDTH - 1:0]  rd_cache_mem_addr,
	input [511:0] rd_cache_mem_result,
	input [`L2_TAG_WIDTH - 1:0] rd_replace_tag,
	input  rd_replace_is_dirty,
	output reg			wr_pci_valid = 0,
	output reg[1:0]	wr_pci_unit = 0,
	output reg[1:0]	wr_pci_strand = 0,
	output reg[2:0]	wr_pci_op = 0,
	output reg[1:0]	wr_pci_way = 0,
	output reg[25:0]	wr_pci_address = 0,
	output reg[511:0]	wr_pci_data = 0,
	output reg[63:0]	wr_pci_mask = 0,
	output reg 		wr_cache_hit = 0,
	output reg[511:0] 	wr_data = 0,
	output reg[`NUM_CORES - 1:0] wr_dir_valid = 0,
	output reg[`NUM_CORES * 2 - 1:0] wr_dir_way = 0,
	output reg[`NUM_CORES * `L1_TAG_WIDTH - 1:0] wr_dir_tag = 0,
	output reg 		wr_has_sm_data = 0,
	output reg wr_update_l2_data = 0,
	output wire[`L2_CACHE_ADDR_WIDTH -1:0] wr_update_addr,
	output reg[511:0] wr_update_data = 0);

	wire[511:0] masked_write_data;

	mask_unit mu(
		.mask_i(rd_pci_mask), 
		.data0_i(rd_pci_data), 
		.data1_i(rd_cache_mem_result), 
		.result_o(masked_write_data));

	always @(posedge clk)
	begin
		if (!stall_pipeline)
		begin
			wr_pci_valid <= #1 rd_pci_valid;
			wr_pci_unit <= #1 rd_pci_unit;
			wr_pci_strand <= #1 rd_pci_strand;
			wr_pci_op <= #1 rd_pci_op;
			wr_pci_way <= #1 rd_pci_way;
			wr_pci_address <= #1 rd_pci_address;
			wr_pci_data <= #1 rd_pci_data;
			wr_pci_mask <= #1 rd_pci_mask;
			wr_has_sm_data <= #1 rd_has_sm_data;
			wr_dir_valid <= #1 rd_dir_valid;
			wr_dir_way <= #1 rd_dir_way;
			wr_dir_tag <= #1 rd_dir_tag;
			wr_cache_hit <= #1 rd_cache_hit;
			wr_pci_op <= #1 rd_pci_op;
			if ((rd_pci_op == `PCI_STORE || rd_pci_op == `PCI_STORE_SYNC) && rd_cache_hit)
				wr_data <= #1 masked_write_data;	// Store
			else
				wr_data <= #1 rd_cache_mem_result;	// Load
		end
	end

	assign wr_update_addr = rd_cache_mem_addr;

	always @*
	begin
		if ((rd_pci_op == `PCI_STORE || rd_pci_op == `PCI_STORE_SYNC) && rd_cache_hit)
		begin
			wr_update_data = masked_write_data;
			wr_update_l2_data = 1;
		end
		else if (rd_has_sm_data)
		begin
			wr_update_data = rd_sm_data;
			wr_update_l2_data = 1;
		end
		else
		begin
			wr_update_data = 0;
			wr_update_l2_data = 0;
		end
	end
endmodule
