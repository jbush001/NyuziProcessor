//
// Level 2 Cache
// 

`include "l2_cache.h"

module l2_cache
	(input						clk,
	input						pci_valid_i,
	output 						pci_ack_o,
	input [1:0]					pci_unit_i,
	input [1:0]					pci_strand_i,
	input [2:0]					pci_op_i,
	input [1:0]					pci_way_i,
	input [25:0]				pci_address_i,
	input [511:0]				pci_data_i,
	input [63:0]				pci_mask_i,
	output 					cpi_valid_o,
	output 					cpi_status_o,
	output [1:0]				cpi_unit_o,
	output [1:0]				cpi_strand_o,
	output [1:0]				cpi_op_o,
	output 					cpi_update_o,
	output [1:0]				cpi_way_o,
	output [511:0]			cpi_data_o,

	// System memory interface
	output [31:0]			addr_o,
	output  					request_o,
	input 						ack_i,
	output 					write_o,
	input [31:0]				data_i,
	output [31:0]				data_o);

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
	wire [1:0]	arb_sm_fill_way;	// From l2_cache_arb of l2_cache_arb.v
	wire		dir_cache_hit;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_dirty0;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_dirty1;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_dirty2;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_dirty3;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_has_sm_data;	// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_hit_way;		// From l2_cache_dir of l2_cache_dir.v
	wire [`NUM_CORES*`L1_TAG_WIDTH-1:0] dir_l1_tag;// From l2_cache_dir of l2_cache_dir.v
	wire [`NUM_CORES-1:0] dir_l1_valid;	// From l2_cache_dir of l2_cache_dir.v
	wire [`NUM_CORES*2-1:0] dir_l1_way;	// From l2_cache_dir of l2_cache_dir.v
	wire [25:0]	dir_pci_address;	// From l2_cache_dir of l2_cache_dir.v
	wire [511:0]	dir_pci_data;		// From l2_cache_dir of l2_cache_dir.v
	wire [63:0]	dir_pci_mask;		// From l2_cache_dir of l2_cache_dir.v
	wire [2:0]	dir_pci_op;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_pci_strand;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_pci_unit;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_pci_valid;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_pci_way;		// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_TAG_WIDTH-1:0] dir_replace_tag;// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_replace_way;	// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_SET_INDEX_WIDTH-1:0] dir_request_set;// From l2_cache_dir of l2_cache_dir.v
	wire [511:0]	dir_sm_data;		// From l2_cache_dir of l2_cache_dir.v
	wire		rd_cache_hit;		// From l2_cache_read of l2_cache_read.v
	wire [`L2_CACHE_ADDR_WIDTH-1:0] rd_cache_mem_addr;// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_cache_mem_result;	// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES*`L1_TAG_WIDTH-1:0] rd_dir_tag;// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES-1:0] rd_dir_valid;	// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES*2-1:0] rd_dir_way;	// From l2_cache_read of l2_cache_read.v
	wire		rd_has_sm_data;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_hit_way;		// From l2_cache_read of l2_cache_read.v
	wire [25:0]	rd_pci_address;		// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_pci_data;		// From l2_cache_read of l2_cache_read.v
	wire [63:0]	rd_pci_mask;		// From l2_cache_read of l2_cache_read.v
	wire [2:0]	rd_pci_op;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_pci_strand;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_pci_unit;		// From l2_cache_read of l2_cache_read.v
	wire		rd_pci_valid;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_pci_way;		// From l2_cache_read of l2_cache_read.v
	wire		rd_replace_is_dirty;	// From l2_cache_read of l2_cache_read.v
	wire [`L2_TAG_WIDTH-1:0] rd_replace_tag;// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_replace_way;		// From l2_cache_read of l2_cache_read.v
	wire [`L2_SET_INDEX_WIDTH-1:0] rd_request_set;// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_sm_data;		// From l2_cache_read of l2_cache_read.v
	wire		smi_data_ready;		// From l2_cache_smi of l2_cache_smi.v
	wire [1:0]	smi_fill_way;		// From l2_cache_smi of l2_cache_smi.v
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
	wire [25:0]	tag_pci_address;	// From l2_cache_tag of l2_cache_tag.v
	wire [511:0]	tag_pci_data;		// From l2_cache_tag of l2_cache_tag.v
	wire [63:0]	tag_pci_mask;		// From l2_cache_tag of l2_cache_tag.v
	wire [2:0]	tag_pci_op;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_pci_strand;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_pci_unit;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_pci_valid;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_pci_way;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_replace_way;	// From l2_cache_tag of l2_cache_tag.v
	wire [511:0]	tag_sm_data;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_sm_fill_way;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_tag0;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_tag1;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_tag2;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_tag3;	// From l2_cache_tag of l2_cache_tag.v
	wire		tag_valid0;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_valid1;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_valid2;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_valid3;		// From l2_cache_tag of l2_cache_tag.v
	wire		wr_cache_hit;		// From l2_cache_write of l2_cache_write.v
	wire [511:0]	wr_data;		// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES*`L1_TAG_WIDTH-1:0] wr_dir_tag;// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES-1:0] wr_dir_valid;	// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES*2-1:0] wr_dir_way;	// From l2_cache_write of l2_cache_write.v
	wire		wr_has_sm_data;		// From l2_cache_write of l2_cache_write.v
	wire [25:0]	wr_pci_address;		// From l2_cache_write of l2_cache_write.v
	wire [511:0]	wr_pci_data;		// From l2_cache_write of l2_cache_write.v
	wire [63:0]	wr_pci_mask;		// From l2_cache_write of l2_cache_write.v
	wire [2:0]	wr_pci_op;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_pci_strand;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_pci_unit;		// From l2_cache_write of l2_cache_write.v
	wire		wr_pci_valid;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_pci_way;		// From l2_cache_write of l2_cache_write.v
	wire [`L2_CACHE_ADDR_WIDTH-1:0] wr_update_addr;// From l2_cache_write of l2_cache_write.v
	wire [511:0]	wr_update_data;		// From l2_cache_write of l2_cache_write.v
	wire		wr_update_l2_data;	// From l2_cache_write of l2_cache_write.v
	// End of automatics

	l2_cache_arb l2_cache_arb(/*AUTOINST*/
				  // Outputs
				  .pci_ack_o		(pci_ack_o),
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
				  .arb_sm_fill_way	(arb_sm_fill_way[1:0]),
				  // Inputs
				  .clk			(clk),
				  .stall_pipeline	(stall_pipeline),
				  .pci_valid_i		(pci_valid_i),
				  .pci_unit_i		(pci_unit_i[1:0]),
				  .pci_strand_i		(pci_strand_i[1:0]),
				  .pci_op_i		(pci_op_i[2:0]),
				  .pci_way_i		(pci_way_i[1:0]),
				  .pci_address_i	(pci_address_i[25:0]),
				  .pci_data_i		(pci_data_i[511:0]),
				  .pci_mask_i		(pci_mask_i[63:0]),
				  .smi_pci_unit		(smi_pci_unit[1:0]),
				  .smi_pci_strand	(smi_pci_strand[1:0]),
				  .smi_pci_op		(smi_pci_op[2:0]),
				  .smi_pci_way		(smi_pci_way[1:0]),
				  .smi_pci_address	(smi_pci_address[25:0]),
				  .smi_pci_data		(smi_pci_data[511:0]),
				  .smi_pci_mask		(smi_pci_mask[63:0]),
				  .smi_load_buffer_vec	(smi_load_buffer_vec[511:0]),
				  .smi_data_ready	(smi_data_ready),
				  .smi_fill_way		(smi_fill_way[1:0]));

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
				    .tag_sm_fill_way	(tag_sm_fill_way[1:0]),
				    .tag_replace_way	(tag_replace_way[1:0]),
				    .tag_tag0		(tag_tag0[`L2_TAG_WIDTH-1:0]),
				    .tag_tag1		(tag_tag1[`L2_TAG_WIDTH-1:0]),
				    .tag_tag2		(tag_tag2[`L2_TAG_WIDTH-1:0]),
				    .tag_tag3		(tag_tag3[`L2_TAG_WIDTH-1:0]),
				    .tag_valid0		(tag_valid0),
				    .tag_valid1		(tag_valid1),
				    .tag_valid2		(tag_valid2),
				    .tag_valid3		(tag_valid3),
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
				    .arb_sm_fill_way	(arb_sm_fill_way[1:0]));

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
				  .dir_hit_way		(dir_hit_way[1:0]),
				  .dir_replace_way	(dir_replace_way[1:0]),
				  .dir_cache_hit	(dir_cache_hit),
				  .dir_replace_tag	(dir_replace_tag[`L2_TAG_WIDTH-1:0]),
				  .dir_l1_valid		(dir_l1_valid[`NUM_CORES-1:0]),
				  .dir_l1_way		(dir_l1_way[`NUM_CORES*2-1:0]),
				  .dir_l1_tag		(dir_l1_tag[`NUM_CORES*`L1_TAG_WIDTH-1:0]),
				  .dir_request_set	(dir_request_set[`L2_SET_INDEX_WIDTH-1:0]),
				  .dir_dirty0		(dir_dirty0),
				  .dir_dirty1		(dir_dirty1),
				  .dir_dirty2		(dir_dirty2),
				  .dir_dirty3		(dir_dirty3),
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
				  .tag_sm_fill_way	(tag_sm_fill_way[1:0]),
				  .tag_replace_way	(tag_replace_way[1:0]),
				  .tag_tag0		(tag_tag0[`L2_TAG_WIDTH-1:0]),
				  .tag_tag1		(tag_tag1[`L2_TAG_WIDTH-1:0]),
				  .tag_tag2		(tag_tag2[`L2_TAG_WIDTH-1:0]),
				  .tag_tag3		(tag_tag3[`L2_TAG_WIDTH-1:0]),
				  .tag_valid0		(tag_valid0),
				  .tag_valid1		(tag_valid1),
				  .tag_valid2		(tag_valid2),
				  .tag_valid3		(tag_valid3));

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
				    .rd_hit_way		(rd_hit_way[1:0]),
				    .rd_replace_way	(rd_replace_way[1:0]),
				    .rd_cache_hit	(rd_cache_hit),
				    .rd_dir_valid	(rd_dir_valid[`NUM_CORES-1:0]),
				    .rd_dir_way		(rd_dir_way[`NUM_CORES*2-1:0]),
				    .rd_dir_tag		(rd_dir_tag[`NUM_CORES*`L1_TAG_WIDTH-1:0]),
				    .rd_request_set	(rd_request_set[`L2_SET_INDEX_WIDTH-1:0]),
				    .rd_cache_mem_addr	(rd_cache_mem_addr[`L2_CACHE_ADDR_WIDTH-1:0]),
				    .rd_cache_mem_result(rd_cache_mem_result[511:0]),
				    .rd_replace_tag	(rd_replace_tag[`L2_TAG_WIDTH-1:0]),
				    .rd_replace_is_dirty(rd_replace_is_dirty),
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
				    .dir_hit_way	(dir_hit_way[1:0]),
				    .dir_replace_way	(dir_replace_way[1:0]),
				    .dir_cache_hit	(dir_cache_hit),
				    .dir_replace_tag	(dir_replace_tag[`L2_TAG_WIDTH-1:0]),
				    .dir_l1_valid	(dir_l1_valid[`NUM_CORES-1:0]),
				    .dir_l1_way		(dir_l1_way[`NUM_CORES*2-1:0]),
				    .dir_l1_tag		(dir_l1_tag[`NUM_CORES*`L1_TAG_WIDTH-1:0]),
				    .dir_request_set	(dir_request_set[`L2_SET_INDEX_WIDTH-1:0]),
				    .dir_dirty0		(dir_dirty0),
				    .dir_dirty1		(dir_dirty1),
				    .dir_dirty2		(dir_dirty2),
				    .dir_dirty3		(dir_dirty3),
				    .wr_update_l2_data	(wr_update_l2_data),
				    .wr_update_addr	(wr_update_addr[`L2_CACHE_ADDR_WIDTH-1:0]),
				    .wr_update_data	(wr_update_data[511:0]));

	l2_cache_write l2_cache_write(/*AUTOINST*/
				      // Outputs
				      .wr_pci_valid	(wr_pci_valid),
				      .wr_pci_unit	(wr_pci_unit[1:0]),
				      .wr_pci_strand	(wr_pci_strand[1:0]),
				      .wr_pci_op	(wr_pci_op[2:0]),
				      .wr_pci_way	(wr_pci_way[1:0]),
				      .wr_pci_address	(wr_pci_address[25:0]),
				      .wr_pci_data	(wr_pci_data[511:0]),
				      .wr_pci_mask	(wr_pci_mask[63:0]),
				      .wr_cache_hit	(wr_cache_hit),
				      .wr_data		(wr_data[511:0]),
				      .wr_dir_valid	(wr_dir_valid[`NUM_CORES-1:0]),
				      .wr_dir_way	(wr_dir_way[`NUM_CORES*2-1:0]),
				      .wr_dir_tag	(wr_dir_tag[`NUM_CORES*`L1_TAG_WIDTH-1:0]),
				      .wr_has_sm_data	(wr_has_sm_data),
				      .wr_update_l2_data(wr_update_l2_data),
				      .wr_update_addr	(wr_update_addr[`L2_CACHE_ADDR_WIDTH-1:0]),
				      .wr_update_data	(wr_update_data[511:0]),
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
				      .rd_hit_way	(rd_hit_way[1:0]),
				      .rd_replace_way	(rd_replace_way[1:0]),
				      .rd_cache_hit	(rd_cache_hit),
				      .rd_dir_valid	(rd_dir_valid[`NUM_CORES-1:0]),
				      .rd_dir_way	(rd_dir_way[`NUM_CORES*2-1:0]),
				      .rd_dir_tag	(rd_dir_tag[`NUM_CORES*`L1_TAG_WIDTH-1:0]),
				      .rd_request_set	(rd_request_set[`L2_SET_INDEX_WIDTH-1:0]),
				      .rd_cache_mem_addr(rd_cache_mem_addr[`L2_CACHE_ADDR_WIDTH-1:0]),
				      .rd_cache_mem_result(rd_cache_mem_result[511:0]),
				      .rd_replace_tag	(rd_replace_tag[`L2_TAG_WIDTH-1:0]),
				      .rd_replace_is_dirty(rd_replace_is_dirty));

	l2_cache_response l2_cache_response(/*AUTOINST*/
					    // Outputs
					    .cpi_valid_o	(cpi_valid_o),
					    .cpi_status_o	(cpi_status_o),
					    .cpi_unit_o		(cpi_unit_o[1:0]),
					    .cpi_strand_o	(cpi_strand_o[1:0]),
					    .cpi_op_o		(cpi_op_o[1:0]),
					    .cpi_update_o	(cpi_update_o),
					    .cpi_way_o		(cpi_way_o[1:0]),
					    .cpi_data_o		(cpi_data_o[511:0]),
					    // Inputs
					    .clk		(clk),
					    .wr_pci_valid	(wr_pci_valid),
					    .wr_pci_unit	(wr_pci_unit[1:0]),
					    .wr_pci_strand	(wr_pci_strand[1:0]),
					    .wr_pci_op		(wr_pci_op[2:0]),
					    .wr_pci_way		(wr_pci_way[1:0]),
					    .wr_data		(wr_data[511:0]),
					    .wr_dir_valid	(wr_dir_valid),
					    .wr_dir_way		(wr_dir_way[1:0]),
					    .wr_cache_hit	(wr_cache_hit),
					    .wr_has_sm_data	(wr_has_sm_data));

	l2_cache_smi l2_cache_smi(/*AUTOINST*/
				  // Outputs
				  .stall_pipeline	(stall_pipeline),
				  .smi_pci_unit		(smi_pci_unit[1:0]),
				  .smi_pci_strand	(smi_pci_strand[1:0]),
				  .smi_pci_op		(smi_pci_op[2:0]),
				  .smi_pci_way		(smi_pci_way[1:0]),
				  .smi_pci_address	(smi_pci_address[25:0]),
				  .smi_pci_data		(smi_pci_data[511:0]),
				  .smi_pci_mask		(smi_pci_mask[63:0]),
				  .smi_load_buffer_vec	(smi_load_buffer_vec[511:0]),
				  .smi_data_ready	(smi_data_ready),
				  .smi_fill_way		(smi_fill_way[1:0]),
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
				  .rd_sm_data		(rd_sm_data[511:0]),
				  .rd_hit_way		(rd_hit_way[1:0]),
				  .rd_replace_way	(rd_replace_way[1:0]),
				  .rd_cache_hit		(rd_cache_hit),
				  .rd_cache_mem_result	(rd_cache_mem_result[511:0]),
				  .rd_replace_tag	(rd_replace_tag[`L2_TAG_WIDTH-1:0]),
				  .rd_replace_is_dirty	(rd_replace_is_dirty),
				  .ack_i		(ack_i),
				  .data_i		(data_i[31:0]));

endmodule
