//
// Level 2 Cache
// 
// The level 2 cache is a six stage pipeline.  Cache misses are queued
// in a system memory queue, where a state machine transfers memory to
// and from system memory.  When a transaction is finished, the command
// is reissued into the L2 cache, where it will update the L2 state.
//

`include "l2_cache.h"

module l2_cache
	(input                  clk,
	input                   pci_valid,
	output                  pci_ack,
	input [1:0]             pci_unit,
	input [1:0]             pci_strand,
	input [2:0]             pci_op,
	input [1:0]             pci_way,
	input [25:0]            pci_address,
	input [511:0]           pci_data,
	input [63:0]            pci_mask,
	output                  cpi_valid,
	output                  cpi_status,
	output [1:0]            cpi_unit,
	output [1:0]            cpi_strand,
	output [1:0]            cpi_op,
	output                  cpi_update,
	output [1:0]            cpi_way,
	output [511:0]          cpi_data,

	// System memory interface
	output [31:0]           addr_o,
	output                  request_o,
	input                   ack_i,
	output                  write_o,
	input [31:0]            data_i,
	output [31:0]           data_o);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		arb_has_sm_data;	// From l2_cache_arb of l2_cache_arb.v
	wire [25:0]	arb_pci_address;	// From l2_cache_arb of l2_cache_arb.v
	wire [511:0]	arb_pci_data;		// From l2_cache_arb of l2_cache_arb.v
	wire [63:0]	arb_pci_mask;		// From l2_cache_arb of l2_cache_arb.v
	wire [2:0]	arb_pci_op;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_pci_strand;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_pci_unit;		// From l2_cache_arb of l2_cache_arb.v
	wire		arb_pci_valid;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_pci_way;		// From l2_cache_arb of l2_cache_arb.v
	wire [511:0]	arb_sm_data;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_sm_fill_l2_way;	// From l2_cache_arb of l2_cache_arb.v
	wire		dir_cache_hit;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_has_sm_data;	// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_hit_l2_way;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l1_has_line;	// From l2_cache_dir of l2_cache_dir.v
	wire [`NUM_CORES*2-1:0] dir_l1_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2_dirty0;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2_dirty1;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2_dirty2;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2_dirty3;		// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_TAG_WIDTH-1:0] dir_old_l2_tag;// From l2_cache_dir of l2_cache_dir.v
	wire [25:0]	dir_pci_address;	// From l2_cache_dir of l2_cache_dir.v
	wire [511:0]	dir_pci_data;		// From l2_cache_dir of l2_cache_dir.v
	wire [63:0]	dir_pci_mask;		// From l2_cache_dir of l2_cache_dir.v
	wire [2:0]	dir_pci_op;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_pci_strand;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_pci_unit;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_pci_valid;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_pci_way;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_replace_l2_way;	// From l2_cache_dir of l2_cache_dir.v
	wire [511:0]	dir_sm_data;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_sm_fill_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		duplicate_request;	// From l2_cache_pending_miss of l2_cache_pending_miss.v
	wire		rd_cache_hit;		// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_cache_mem_result;	// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES*2-1:0] rd_dir_l1_way;	// From l2_cache_read of l2_cache_read.v
	wire		rd_has_sm_data;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_hit_l2_way;		// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES-1:0] rd_l1_has_line;	// From l2_cache_read of l2_cache_read.v
	wire		rd_line_is_dirty;	// From l2_cache_read of l2_cache_read.v
	wire [`L2_TAG_WIDTH-1:0] rd_old_l2_tag;	// From l2_cache_read of l2_cache_read.v
	wire [25:0]	rd_pci_address;		// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_pci_data;		// From l2_cache_read of l2_cache_read.v
	wire [63:0]	rd_pci_mask;		// From l2_cache_read of l2_cache_read.v
	wire [2:0]	rd_pci_op;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_pci_strand;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_pci_unit;		// From l2_cache_read of l2_cache_read.v
	wire		rd_pci_valid;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_pci_way;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_replace_l2_way;	// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_sm_data;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_sm_fill_l2_way;	// From l2_cache_read of l2_cache_read.v
	wire		rd_store_sync_success;	// From l2_cache_read of l2_cache_read.v
	wire		smi_data_ready;		// From l2_cache_smi of l2_cache_smi.v
	wire		smi_duplicate_request;	// From l2_cache_smi of l2_cache_smi.v
	wire [1:0]	smi_fill_l2_way;	// From l2_cache_smi of l2_cache_smi.v
	wire [511:0]	smi_load_buffer_vec;	// From l2_cache_smi of l2_cache_smi.v
	wire [25:0]	smi_pci_address;	// From l2_cache_smi of l2_cache_smi.v
	wire [511:0]	smi_pci_data;		// From l2_cache_smi of l2_cache_smi.v
	wire [63:0]	smi_pci_mask;		// From l2_cache_smi of l2_cache_smi.v
	wire [2:0]	smi_pci_op;		// From l2_cache_smi of l2_cache_smi.v
	wire [1:0]	smi_pci_strand;		// From l2_cache_smi of l2_cache_smi.v
	wire [1:0]	smi_pci_unit;		// From l2_cache_smi of l2_cache_smi.v
	wire [1:0]	smi_pci_way;		// From l2_cache_smi of l2_cache_smi.v
	wire		stall_pipeline;		// From l2_cache_smi of l2_cache_smi.v
	wire		tag_has_sm_data;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_l2_tag0;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_l2_tag1;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_l2_tag2;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_l2_tag3;	// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_valid0;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_valid1;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_valid2;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_valid3;		// From l2_cache_tag of l2_cache_tag.v
	wire [25:0]	tag_pci_address;	// From l2_cache_tag of l2_cache_tag.v
	wire [511:0]	tag_pci_data;		// From l2_cache_tag of l2_cache_tag.v
	wire [63:0]	tag_pci_mask;		// From l2_cache_tag of l2_cache_tag.v
	wire [2:0]	tag_pci_op;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_pci_strand;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_pci_unit;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_pci_valid;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_pci_way;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_replace_l2_way;	// From l2_cache_tag of l2_cache_tag.v
	wire [511:0]	tag_sm_data;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_sm_fill_l2_way;	// From l2_cache_tag of l2_cache_tag.v
	wire		wr_cache_hit;		// From l2_cache_write of l2_cache_write.v
	wire [`L2_CACHE_ADDR_WIDTH-1:0] wr_cache_write_index;// From l2_cache_write of l2_cache_write.v
	wire [511:0]	wr_data;		// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES*2-1:0] wr_dir_l1_way;	// From l2_cache_write of l2_cache_write.v
	wire		wr_has_sm_data;		// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES-1:0] wr_l1_has_line;	// From l2_cache_write of l2_cache_write.v
	wire [2:0]	wr_pci_op;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_pci_strand;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_pci_unit;		// From l2_cache_write of l2_cache_write.v
	wire		wr_pci_valid;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_pci_way;		// From l2_cache_write of l2_cache_write.v
	wire		wr_store_sync_success;	// From l2_cache_write of l2_cache_write.v
	wire [511:0]	wr_update_data;		// From l2_cache_write of l2_cache_write.v
	wire		wr_update_l2_data;	// From l2_cache_write of l2_cache_write.v
	// End of automatics

	l2_cache_arb l2_cache_arb(/*AUTOINST*/
				  // Outputs
				  .pci_ack		(pci_ack),
				  .arb_pci_valid	(arb_pci_valid),
				  .arb_pci_unit		(arb_pci_unit[1:0]),
				  .arb_pci_strand	(arb_pci_strand[1:0]),
				  .arb_pci_op		(arb_pci_op[2:0]),
				  .arb_pci_way		(arb_pci_way[1:0]),
				  .arb_pci_address	(arb_pci_address[25:0]),
				  .arb_pci_data		(arb_pci_data[511:0]),
				  .arb_pci_mask		(arb_pci_mask[63:0]),
				  .arb_has_sm_data	(arb_has_sm_data),
				  .arb_sm_data		(arb_sm_data[511:0]),
				  .arb_sm_fill_l2_way	(arb_sm_fill_l2_way[1:0]),
				  // Inputs
				  .clk			(clk),
				  .stall_pipeline	(stall_pipeline),
				  .pci_valid		(pci_valid),
				  .pci_unit		(pci_unit[1:0]),
				  .pci_strand		(pci_strand[1:0]),
				  .pci_op		(pci_op[2:0]),
				  .pci_way		(pci_way[1:0]),
				  .pci_address		(pci_address[25:0]),
				  .pci_data		(pci_data[511:0]),
				  .pci_mask		(pci_mask[63:0]),
				  .smi_pci_unit		(smi_pci_unit[1:0]),
				  .smi_pci_strand	(smi_pci_strand[1:0]),
				  .smi_pci_op		(smi_pci_op[2:0]),
				  .smi_pci_way		(smi_pci_way[1:0]),
				  .smi_pci_address	(smi_pci_address[25:0]),
				  .smi_pci_data		(smi_pci_data[511:0]),
				  .smi_pci_mask		(smi_pci_mask[63:0]),
				  .smi_load_buffer_vec	(smi_load_buffer_vec[511:0]),
				  .smi_data_ready	(smi_data_ready),
				  .smi_fill_l2_way	(smi_fill_l2_way[1:0]),
				  .smi_duplicate_request(smi_duplicate_request));

	l2_cache_tag l2_cache_tag  (/*AUTOINST*/
				    // Outputs
				    .tag_pci_valid	(tag_pci_valid),
				    .tag_pci_unit	(tag_pci_unit[1:0]),
				    .tag_pci_strand	(tag_pci_strand[1:0]),
				    .tag_pci_op		(tag_pci_op[2:0]),
				    .tag_pci_way	(tag_pci_way[1:0]),
				    .tag_pci_address	(tag_pci_address[25:0]),
				    .tag_pci_data	(tag_pci_data[511:0]),
				    .tag_pci_mask	(tag_pci_mask[63:0]),
				    .tag_has_sm_data	(tag_has_sm_data),
				    .tag_sm_data	(tag_sm_data[511:0]),
				    .tag_sm_fill_l2_way	(tag_sm_fill_l2_way[1:0]),
				    .tag_replace_l2_way	(tag_replace_l2_way[1:0]),
				    .tag_l2_tag0	(tag_l2_tag0[`L2_TAG_WIDTH-1:0]),
				    .tag_l2_tag1	(tag_l2_tag1[`L2_TAG_WIDTH-1:0]),
				    .tag_l2_tag2	(tag_l2_tag2[`L2_TAG_WIDTH-1:0]),
				    .tag_l2_tag3	(tag_l2_tag3[`L2_TAG_WIDTH-1:0]),
				    .tag_l2_valid0	(tag_l2_valid0),
				    .tag_l2_valid1	(tag_l2_valid1),
				    .tag_l2_valid2	(tag_l2_valid2),
				    .tag_l2_valid3	(tag_l2_valid3),
				    // Inputs
				    .clk		(clk),
				    .stall_pipeline	(stall_pipeline),
				    .arb_pci_valid	(arb_pci_valid),
				    .arb_pci_unit	(arb_pci_unit[1:0]),
				    .arb_pci_strand	(arb_pci_strand[1:0]),
				    .arb_pci_op		(arb_pci_op[2:0]),
				    .arb_pci_way	(arb_pci_way[1:0]),
				    .arb_pci_address	(arb_pci_address[25:0]),
				    .arb_pci_data	(arb_pci_data[511:0]),
				    .arb_pci_mask	(arb_pci_mask[63:0]),
				    .arb_has_sm_data	(arb_has_sm_data),
				    .arb_sm_data	(arb_sm_data[511:0]),
				    .arb_sm_fill_l2_way	(arb_sm_fill_l2_way[1:0]));

	l2_cache_dir l2_cache_dir(/*AUTOINST*/
				  // Outputs
				  .dir_pci_valid	(dir_pci_valid),
				  .dir_pci_unit		(dir_pci_unit[1:0]),
				  .dir_pci_strand	(dir_pci_strand[1:0]),
				  .dir_pci_op		(dir_pci_op[2:0]),
				  .dir_pci_way		(dir_pci_way[1:0]),
				  .dir_pci_address	(dir_pci_address[25:0]),
				  .dir_pci_data		(dir_pci_data[511:0]),
				  .dir_pci_mask		(dir_pci_mask[63:0]),
				  .dir_has_sm_data	(dir_has_sm_data),
				  .dir_sm_data		(dir_sm_data[511:0]),
				  .dir_sm_fill_way	(dir_sm_fill_way[1:0]),
				  .dir_hit_l2_way	(dir_hit_l2_way[1:0]),
				  .dir_replace_l2_way	(dir_replace_l2_way[1:0]),
				  .dir_cache_hit	(dir_cache_hit),
				  .dir_old_l2_tag	(dir_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				  .dir_l1_has_line	(dir_l1_has_line),
				  .dir_l1_way		(dir_l1_way[`NUM_CORES*2-1:0]),
				  .dir_l2_dirty0	(dir_l2_dirty0),
				  .dir_l2_dirty1	(dir_l2_dirty1),
				  .dir_l2_dirty2	(dir_l2_dirty2),
				  .dir_l2_dirty3	(dir_l2_dirty3),
				  // Inputs
				  .clk			(clk),
				  .stall_pipeline	(stall_pipeline),
				  .tag_pci_valid	(tag_pci_valid),
				  .tag_pci_unit		(tag_pci_unit[1:0]),
				  .tag_pci_strand	(tag_pci_strand[1:0]),
				  .tag_pci_op		(tag_pci_op[2:0]),
				  .tag_pci_way		(tag_pci_way[1:0]),
				  .tag_pci_address	(tag_pci_address[25:0]),
				  .tag_pci_data		(tag_pci_data[511:0]),
				  .tag_pci_mask		(tag_pci_mask[63:0]),
				  .tag_has_sm_data	(tag_has_sm_data),
				  .tag_sm_data		(tag_sm_data[511:0]),
				  .tag_sm_fill_l2_way	(tag_sm_fill_l2_way[1:0]),
				  .tag_replace_l2_way	(tag_replace_l2_way[1:0]),
				  .tag_l2_tag0		(tag_l2_tag0[`L2_TAG_WIDTH-1:0]),
				  .tag_l2_tag1		(tag_l2_tag1[`L2_TAG_WIDTH-1:0]),
				  .tag_l2_tag2		(tag_l2_tag2[`L2_TAG_WIDTH-1:0]),
				  .tag_l2_tag3		(tag_l2_tag3[`L2_TAG_WIDTH-1:0]),
				  .tag_l2_valid0	(tag_l2_valid0),
				  .tag_l2_valid1	(tag_l2_valid1),
				  .tag_l2_valid2	(tag_l2_valid2),
				  .tag_l2_valid3	(tag_l2_valid3));

	l2_cache_read l2_cache_read(/*AUTOINST*/
				    // Outputs
				    .rd_pci_valid	(rd_pci_valid),
				    .rd_pci_unit	(rd_pci_unit[1:0]),
				    .rd_pci_strand	(rd_pci_strand[1:0]),
				    .rd_pci_op		(rd_pci_op[2:0]),
				    .rd_pci_way		(rd_pci_way[1:0]),
				    .rd_pci_address	(rd_pci_address[25:0]),
				    .rd_pci_data	(rd_pci_data[511:0]),
				    .rd_pci_mask	(rd_pci_mask[63:0]),
				    .rd_has_sm_data	(rd_has_sm_data),
				    .rd_sm_data		(rd_sm_data[511:0]),
				    .rd_sm_fill_l2_way	(rd_sm_fill_l2_way[1:0]),
				    .rd_hit_l2_way	(rd_hit_l2_way[1:0]),
				    .rd_replace_l2_way	(rd_replace_l2_way[1:0]),
				    .rd_cache_hit	(rd_cache_hit),
				    .rd_l1_has_line	(rd_l1_has_line[`NUM_CORES-1:0]),
				    .rd_dir_l1_way	(rd_dir_l1_way[`NUM_CORES*2-1:0]),
				    .rd_cache_mem_result(rd_cache_mem_result[511:0]),
				    .rd_old_l2_tag	(rd_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				    .rd_line_is_dirty	(rd_line_is_dirty),
				    .rd_store_sync_success(rd_store_sync_success),
				    // Inputs
				    .clk		(clk),
				    .stall_pipeline	(stall_pipeline),
				    .dir_pci_valid	(dir_pci_valid),
				    .dir_pci_unit	(dir_pci_unit[1:0]),
				    .dir_pci_strand	(dir_pci_strand[1:0]),
				    .dir_pci_op		(dir_pci_op[2:0]),
				    .dir_pci_way	(dir_pci_way[1:0]),
				    .dir_pci_address	(dir_pci_address[25:0]),
				    .dir_pci_data	(dir_pci_data[511:0]),
				    .dir_pci_mask	(dir_pci_mask[63:0]),
				    .dir_has_sm_data	(dir_has_sm_data),
				    .dir_sm_data	(dir_sm_data[511:0]),
				    .dir_hit_l2_way	(dir_hit_l2_way[1:0]),
				    .dir_replace_l2_way	(dir_replace_l2_way[1:0]),
				    .dir_cache_hit	(dir_cache_hit),
				    .dir_old_l2_tag	(dir_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				    .dir_l1_has_line	(dir_l1_has_line),
				    .dir_l1_way		(dir_l1_way[`NUM_CORES*2-1:0]),
				    .dir_l2_dirty0	(dir_l2_dirty0),
				    .dir_l2_dirty1	(dir_l2_dirty1),
				    .dir_l2_dirty2	(dir_l2_dirty2),
				    .dir_l2_dirty3	(dir_l2_dirty3),
				    .dir_sm_fill_way	(dir_sm_fill_way[1:0]),
				    .wr_update_l2_data	(wr_update_l2_data),
				    .wr_cache_write_index(wr_cache_write_index[`L2_CACHE_ADDR_WIDTH-1:0]),
				    .wr_update_data	(wr_update_data[511:0]));

	l2_cache_write l2_cache_write(/*AUTOINST*/
				      // Outputs
				      .wr_pci_valid	(wr_pci_valid),
				      .wr_pci_unit	(wr_pci_unit[1:0]),
				      .wr_pci_strand	(wr_pci_strand[1:0]),
				      .wr_pci_op	(wr_pci_op[2:0]),
				      .wr_pci_way	(wr_pci_way[1:0]),
				      .wr_cache_hit	(wr_cache_hit),
				      .wr_data		(wr_data[511:0]),
				      .wr_l1_has_line	(wr_l1_has_line[`NUM_CORES-1:0]),
				      .wr_dir_l1_way	(wr_dir_l1_way[`NUM_CORES*2-1:0]),
				      .wr_has_sm_data	(wr_has_sm_data),
				      .wr_update_l2_data(wr_update_l2_data),
				      .wr_cache_write_index(wr_cache_write_index[`L2_CACHE_ADDR_WIDTH-1:0]),
				      .wr_update_data	(wr_update_data[511:0]),
				      .wr_store_sync_success(wr_store_sync_success),
				      // Inputs
				      .clk		(clk),
				      .stall_pipeline	(stall_pipeline),
				      .rd_pci_valid	(rd_pci_valid),
				      .rd_pci_unit	(rd_pci_unit[1:0]),
				      .rd_pci_strand	(rd_pci_strand[1:0]),
				      .rd_pci_op	(rd_pci_op[2:0]),
				      .rd_pci_way	(rd_pci_way[1:0]),
				      .rd_pci_address	(rd_pci_address[25:0]),
				      .rd_pci_data	(rd_pci_data[511:0]),
				      .rd_pci_mask	(rd_pci_mask[63:0]),
				      .rd_has_sm_data	(rd_has_sm_data),
				      .rd_sm_data	(rd_sm_data[511:0]),
				      .rd_hit_l2_way	(rd_hit_l2_way[1:0]),
				      .rd_cache_hit	(rd_cache_hit),
				      .rd_l1_has_line	(rd_l1_has_line[`NUM_CORES-1:0]),
				      .rd_dir_l1_way	(rd_dir_l1_way[`NUM_CORES*2-1:0]),
				      .rd_cache_mem_result(rd_cache_mem_result[511:0]),
				      .rd_sm_fill_l2_way(rd_sm_fill_l2_way[1:0]),
				      .rd_store_sync_success(rd_store_sync_success));

	l2_cache_response l2_cache_response(/*AUTOINST*/
					    // Outputs
					    .cpi_valid		(cpi_valid),
					    .cpi_status		(cpi_status),
					    .cpi_unit		(cpi_unit[1:0]),
					    .cpi_strand		(cpi_strand[1:0]),
					    .cpi_op		(cpi_op[1:0]),
					    .cpi_update		(cpi_update),
					    .cpi_way		(cpi_way[1:0]),
					    .cpi_data		(cpi_data[511:0]),
					    // Inputs
					    .clk		(clk),
					    .wr_pci_valid	(wr_pci_valid),
					    .wr_pci_unit	(wr_pci_unit[1:0]),
					    .wr_pci_strand	(wr_pci_strand[1:0]),
					    .wr_pci_op		(wr_pci_op[2:0]),
					    .wr_pci_way		(wr_pci_way[1:0]),
					    .wr_data		(wr_data[511:0]),
					    .wr_l1_has_line	(wr_l1_has_line),
					    .wr_dir_l1_way	(wr_dir_l1_way[1:0]),
					    .wr_cache_hit	(wr_cache_hit),
					    .wr_has_sm_data	(wr_has_sm_data),
					    .wr_store_sync_success(wr_store_sync_success));

	l2_cache_pending_miss l2_cache_pending_miss(/*AUTOINST*/
						    // Outputs
						    .duplicate_request	(duplicate_request),
						    // Inputs
						    .clk		(clk),
						    .rd_pci_valid	(rd_pci_valid),
						    .rd_pci_address	(rd_pci_address[25:0]),
						    .rd_cache_hit	(rd_cache_hit),
						    .rd_has_sm_data	(rd_has_sm_data));

	l2_cache_smi l2_cache_smi(/*AUTOINST*/
				  // Outputs
				  .stall_pipeline	(stall_pipeline),
				  .smi_duplicate_request(smi_duplicate_request),
				  .smi_pci_unit		(smi_pci_unit[1:0]),
				  .smi_pci_strand	(smi_pci_strand[1:0]),
				  .smi_pci_op		(smi_pci_op[2:0]),
				  .smi_pci_way		(smi_pci_way[1:0]),
				  .smi_pci_address	(smi_pci_address[25:0]),
				  .smi_pci_data		(smi_pci_data[511:0]),
				  .smi_pci_mask		(smi_pci_mask[63:0]),
				  .smi_load_buffer_vec	(smi_load_buffer_vec[511:0]),
				  .smi_data_ready	(smi_data_ready),
				  .smi_fill_l2_way	(smi_fill_l2_way[1:0]),
				  .addr_o		(addr_o[31:0]),
				  .request_o		(request_o),
				  .write_o		(write_o),
				  .data_o		(data_o[31:0]),
				  // Inputs
				  .clk			(clk),
				  .rd_pci_valid		(rd_pci_valid),
				  .rd_pci_unit		(rd_pci_unit[1:0]),
				  .rd_pci_strand	(rd_pci_strand[1:0]),
				  .rd_pci_op		(rd_pci_op[2:0]),
				  .rd_pci_way		(rd_pci_way[1:0]),
				  .rd_pci_address	(rd_pci_address[25:0]),
				  .rd_pci_data		(rd_pci_data[511:0]),
				  .rd_pci_mask		(rd_pci_mask[63:0]),
				  .rd_has_sm_data	(rd_has_sm_data),
				  .rd_replace_l2_way	(rd_replace_l2_way[1:0]),
				  .rd_cache_hit		(rd_cache_hit),
				  .rd_cache_mem_result	(rd_cache_mem_result[511:0]),
				  .rd_old_l2_tag	(rd_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				  .rd_line_is_dirty	(rd_line_is_dirty),
				  .duplicate_request	(duplicate_request),
				  .ack_i		(ack_i),
				  .data_i		(data_i[31:0]));
				  
	/////// Performance Counters ////////////////////////////
	reg[63:0] hit_count = 0;
	reg[63:0] miss_count = 0;

	always @(posedge clk)
	begin
		if (dir_pci_valid && !dir_has_sm_data && (dir_pci_op == `PCI_LOAD
			|| dir_pci_op == `PCI_STORE || dir_pci_op == `PCI_LOAD_SYNC
			|| dir_pci_op == `PCI_STORE_SYNC))
		begin
			if (dir_cache_hit)		
				hit_count <= #1 hit_count + 1;
			else
				miss_count <= #1 miss_count + 1;
		end
	end
	
	/////////////////////////////////////////////////////////
endmodule
