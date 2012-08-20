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

`include "l2_cache.h"


//
// Level 2 Cache
// 
// The level 2 cache is a six stage pipeline.  Cache misses are queued
// in a system memory queue, where a state machine transfers memory to
// and from system memory.  When a transaction is finished, the command
// is reissued into the beginning of the pipeline, where it will update 
// the L2 state.
//

module l2_cache
	(input                  clk,
	input                   l2req_valid,
	output                  l2req_ack,
	input [1:0]             l2req_unit,
	input [1:0]             l2req_strand,
	input [2:0]             l2req_op,
	input [1:0]             l2req_way,
	input [25:0]            l2req_address,
	input [511:0]           l2req_data,
	input [63:0]            l2req_mask,
	output                  l2rsp_valid,
	output                  l2rsp_status,
	output [1:0]            l2rsp_unit,
	output [1:0]            l2rsp_strand,
	output [1:0]            l2rsp_op,
	output                  l2rsp_update,
	output [1:0]            l2rsp_way,
	output [511:0]          l2rsp_data,

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
	wire [25:0]	arb_l2req_address;	// From l2_cache_arb of l2_cache_arb.v
	wire [511:0]	arb_l2req_data;		// From l2_cache_arb of l2_cache_arb.v
	wire [63:0]	arb_l2req_mask;		// From l2_cache_arb of l2_cache_arb.v
	wire [2:0]	arb_l2req_op;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_l2req_strand;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_l2req_unit;		// From l2_cache_arb of l2_cache_arb.v
	wire		arb_l2req_valid;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_l2req_way;		// From l2_cache_arb of l2_cache_arb.v
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
	wire [25:0]	dir_l2req_address;	// From l2_cache_dir of l2_cache_dir.v
	wire [511:0]	dir_l2req_data;		// From l2_cache_dir of l2_cache_dir.v
	wire [63:0]	dir_l2req_mask;		// From l2_cache_dir of l2_cache_dir.v
	wire [2:0]	dir_l2req_op;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_l2req_strand;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_l2req_unit;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2req_valid;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_l2req_way;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_replace_l2_way;	// From l2_cache_dir of l2_cache_dir.v
	wire [511:0]	dir_sm_data;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_sm_fill_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		rd_cache_hit;		// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_cache_mem_result;	// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES*2-1:0] rd_dir_l1_way;	// From l2_cache_read of l2_cache_read.v
	wire		rd_has_sm_data;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_hit_l2_way;		// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES-1:0] rd_l1_has_line;	// From l2_cache_read of l2_cache_read.v
	wire		rd_line_is_dirty;	// From l2_cache_read of l2_cache_read.v
	wire [`L2_TAG_WIDTH-1:0] rd_old_l2_tag;	// From l2_cache_read of l2_cache_read.v
	wire [25:0]	rd_l2req_address;		// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_l2req_data;		// From l2_cache_read of l2_cache_read.v
	wire [63:0]	rd_l2req_mask;		// From l2_cache_read of l2_cache_read.v
	wire [2:0]	rd_l2req_op;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_l2req_strand;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_l2req_unit;		// From l2_cache_read of l2_cache_read.v
	wire		rd_l2req_valid;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_l2req_way;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_replace_l2_way;	// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_sm_data;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_sm_fill_l2_way;	// From l2_cache_read of l2_cache_read.v
	wire		rd_store_sync_success;	// From l2_cache_read of l2_cache_read.v
	wire		smi_data_ready;		// From l2_cache_smi of l2_cache_smi.v
	wire		smi_duplicate_request;	// From l2_cache_smi of l2_cache_smi.v
	wire [1:0]	smi_fill_l2_way;	// From l2_cache_smi of l2_cache_smi.v
	wire [511:0]	smi_load_buffer_vec;	// From l2_cache_smi of l2_cache_smi.v
	wire [25:0]	smi_l2req_address;	// From l2_cache_smi of l2_cache_smi.v
	wire [511:0]	smi_l2req_data;		// From l2_cache_smi of l2_cache_smi.v
	wire [63:0]	smi_l2req_mask;		// From l2_cache_smi of l2_cache_smi.v
	wire [2:0]	smi_l2req_op;		// From l2_cache_smi of l2_cache_smi.v
	wire [1:0]	smi_l2req_strand;		// From l2_cache_smi of l2_cache_smi.v
	wire [1:0]	smi_l2req_unit;		// From l2_cache_smi of l2_cache_smi.v
	wire [1:0]	smi_l2req_way;		// From l2_cache_smi of l2_cache_smi.v
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
	wire [25:0]	tag_l2req_address;	// From l2_cache_tag of l2_cache_tag.v
	wire [511:0]	tag_l2req_data;		// From l2_cache_tag of l2_cache_tag.v
	wire [63:0]	tag_l2req_mask;		// From l2_cache_tag of l2_cache_tag.v
	wire [2:0]	tag_l2req_op;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_l2req_strand;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_l2req_unit;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2req_valid;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_l2req_way;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_replace_l2_way;	// From l2_cache_tag of l2_cache_tag.v
	wire [511:0]	tag_sm_data;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_sm_fill_l2_way;	// From l2_cache_tag of l2_cache_tag.v
	wire		wr_cache_hit;		// From l2_cache_write of l2_cache_write.v
	wire [`L2_CACHE_ADDR_WIDTH-1:0] wr_cache_write_index;// From l2_cache_write of l2_cache_write.v
	wire [511:0]	wr_data;		// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES*2-1:0] wr_dir_l1_way;	// From l2_cache_write of l2_cache_write.v
	wire		wr_has_sm_data;		// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES-1:0] wr_l1_has_line;	// From l2_cache_write of l2_cache_write.v
	wire [2:0]	wr_l2req_op;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_l2req_strand;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_l2req_unit;		// From l2_cache_write of l2_cache_write.v
	wire		wr_l2req_valid;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_l2req_way;		// From l2_cache_write of l2_cache_write.v
	wire		wr_store_sync_success;	// From l2_cache_write of l2_cache_write.v
	wire [511:0]	wr_update_data;		// From l2_cache_write of l2_cache_write.v
	wire		wr_update_l2_data;	// From l2_cache_write of l2_cache_write.v
	// End of automatics

	l2_cache_arb l2_cache_arb(/*AUTOINST*/
				  // Outputs
				  .l2req_ack		(l2req_ack),
				  .arb_l2req_valid	(arb_l2req_valid),
				  .arb_l2req_unit		(arb_l2req_unit[1:0]),
				  .arb_l2req_strand	(arb_l2req_strand[1:0]),
				  .arb_l2req_op		(arb_l2req_op[2:0]),
				  .arb_l2req_way		(arb_l2req_way[1:0]),
				  .arb_l2req_address	(arb_l2req_address[25:0]),
				  .arb_l2req_data		(arb_l2req_data[511:0]),
				  .arb_l2req_mask		(arb_l2req_mask[63:0]),
				  .arb_has_sm_data	(arb_has_sm_data),
				  .arb_sm_data		(arb_sm_data[511:0]),
				  .arb_sm_fill_l2_way	(arb_sm_fill_l2_way[1:0]),
				  // Inputs
				  .clk			(clk),
				  .stall_pipeline	(stall_pipeline),
				  .l2req_valid		(l2req_valid),
				  .l2req_unit		(l2req_unit[1:0]),
				  .l2req_strand		(l2req_strand[1:0]),
				  .l2req_op		(l2req_op[2:0]),
				  .l2req_way		(l2req_way[1:0]),
				  .l2req_address		(l2req_address[25:0]),
				  .l2req_data		(l2req_data[511:0]),
				  .l2req_mask		(l2req_mask[63:0]),
				  .smi_l2req_unit		(smi_l2req_unit[1:0]),
				  .smi_l2req_strand	(smi_l2req_strand[1:0]),
				  .smi_l2req_op		(smi_l2req_op[2:0]),
				  .smi_l2req_way		(smi_l2req_way[1:0]),
				  .smi_l2req_address	(smi_l2req_address[25:0]),
				  .smi_l2req_data		(smi_l2req_data[511:0]),
				  .smi_l2req_mask		(smi_l2req_mask[63:0]),
				  .smi_load_buffer_vec	(smi_load_buffer_vec[511:0]),
				  .smi_data_ready	(smi_data_ready),
				  .smi_fill_l2_way	(smi_fill_l2_way[1:0]),
				  .smi_duplicate_request(smi_duplicate_request));

	l2_cache_tag l2_cache_tag  (/*AUTOINST*/
				    // Outputs
				    .tag_l2req_valid	(tag_l2req_valid),
				    .tag_l2req_unit	(tag_l2req_unit[1:0]),
				    .tag_l2req_strand	(tag_l2req_strand[1:0]),
				    .tag_l2req_op		(tag_l2req_op[2:0]),
				    .tag_l2req_way	(tag_l2req_way[1:0]),
				    .tag_l2req_address	(tag_l2req_address[25:0]),
				    .tag_l2req_data	(tag_l2req_data[511:0]),
				    .tag_l2req_mask	(tag_l2req_mask[63:0]),
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
				    .arb_l2req_valid	(arb_l2req_valid),
				    .arb_l2req_unit	(arb_l2req_unit[1:0]),
				    .arb_l2req_strand	(arb_l2req_strand[1:0]),
				    .arb_l2req_op		(arb_l2req_op[2:0]),
				    .arb_l2req_way	(arb_l2req_way[1:0]),
				    .arb_l2req_address	(arb_l2req_address[25:0]),
				    .arb_l2req_data	(arb_l2req_data[511:0]),
				    .arb_l2req_mask	(arb_l2req_mask[63:0]),
				    .arb_has_sm_data	(arb_has_sm_data),
				    .arb_sm_data	(arb_sm_data[511:0]),
				    .arb_sm_fill_l2_way	(arb_sm_fill_l2_way[1:0]));

	l2_cache_dir l2_cache_dir(/*AUTOINST*/
				  // Outputs
				  .dir_l2req_valid	(dir_l2req_valid),
				  .dir_l2req_unit		(dir_l2req_unit[1:0]),
				  .dir_l2req_strand	(dir_l2req_strand[1:0]),
				  .dir_l2req_op		(dir_l2req_op[2:0]),
				  .dir_l2req_way		(dir_l2req_way[1:0]),
				  .dir_l2req_address	(dir_l2req_address[25:0]),
				  .dir_l2req_data		(dir_l2req_data[511:0]),
				  .dir_l2req_mask		(dir_l2req_mask[63:0]),
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
				  .tag_l2req_valid	(tag_l2req_valid),
				  .tag_l2req_unit		(tag_l2req_unit[1:0]),
				  .tag_l2req_strand	(tag_l2req_strand[1:0]),
				  .tag_l2req_op		(tag_l2req_op[2:0]),
				  .tag_l2req_way		(tag_l2req_way[1:0]),
				  .tag_l2req_address	(tag_l2req_address[25:0]),
				  .tag_l2req_data		(tag_l2req_data[511:0]),
				  .tag_l2req_mask		(tag_l2req_mask[63:0]),
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
				    .rd_l2req_valid	(rd_l2req_valid),
				    .rd_l2req_unit	(rd_l2req_unit[1:0]),
				    .rd_l2req_strand	(rd_l2req_strand[1:0]),
				    .rd_l2req_op		(rd_l2req_op[2:0]),
				    .rd_l2req_way		(rd_l2req_way[1:0]),
				    .rd_l2req_address	(rd_l2req_address[25:0]),
				    .rd_l2req_data	(rd_l2req_data[511:0]),
				    .rd_l2req_mask	(rd_l2req_mask[63:0]),
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
				    .dir_l2req_valid	(dir_l2req_valid),
				    .dir_l2req_unit	(dir_l2req_unit[1:0]),
				    .dir_l2req_strand	(dir_l2req_strand[1:0]),
				    .dir_l2req_op		(dir_l2req_op[2:0]),
				    .dir_l2req_way	(dir_l2req_way[1:0]),
				    .dir_l2req_address	(dir_l2req_address[25:0]),
				    .dir_l2req_data	(dir_l2req_data[511:0]),
				    .dir_l2req_mask	(dir_l2req_mask[63:0]),
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
				      .wr_l2req_valid	(wr_l2req_valid),
				      .wr_l2req_unit	(wr_l2req_unit[1:0]),
				      .wr_l2req_strand	(wr_l2req_strand[1:0]),
				      .wr_l2req_op	(wr_l2req_op[2:0]),
				      .wr_l2req_way	(wr_l2req_way[1:0]),
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
				      .rd_l2req_valid	(rd_l2req_valid),
				      .rd_l2req_unit	(rd_l2req_unit[1:0]),
				      .rd_l2req_strand	(rd_l2req_strand[1:0]),
				      .rd_l2req_op	(rd_l2req_op[2:0]),
				      .rd_l2req_way	(rd_l2req_way[1:0]),
				      .rd_l2req_address	(rd_l2req_address[25:0]),
				      .rd_l2req_data	(rd_l2req_data[511:0]),
				      .rd_l2req_mask	(rd_l2req_mask[63:0]),
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
					    .l2rsp_valid		(l2rsp_valid),
					    .l2rsp_status		(l2rsp_status),
					    .l2rsp_unit		(l2rsp_unit[1:0]),
					    .l2rsp_strand		(l2rsp_strand[1:0]),
					    .l2rsp_op		(l2rsp_op[1:0]),
					    .l2rsp_update		(l2rsp_update),
					    .l2rsp_way		(l2rsp_way[1:0]),
					    .l2rsp_data		(l2rsp_data[511:0]),
					    // Inputs
					    .clk		(clk),
					    .wr_l2req_valid	(wr_l2req_valid),
					    .wr_l2req_unit	(wr_l2req_unit[1:0]),
					    .wr_l2req_strand	(wr_l2req_strand[1:0]),
					    .wr_l2req_op		(wr_l2req_op[2:0]),
					    .wr_l2req_way		(wr_l2req_way[1:0]),
					    .wr_data		(wr_data[511:0]),
					    .wr_l1_has_line	(wr_l1_has_line),
					    .wr_dir_l1_way	(wr_dir_l1_way[1:0]),
					    .wr_cache_hit	(wr_cache_hit),
					    .wr_has_sm_data	(wr_has_sm_data),
					    .wr_store_sync_success(wr_store_sync_success));

	l2_cache_smi l2_cache_smi(/*AUTOINST*/
				  // Outputs
				  .stall_pipeline	(stall_pipeline),
				  .smi_duplicate_request(smi_duplicate_request),
				  .smi_l2req_unit		(smi_l2req_unit[1:0]),
				  .smi_l2req_strand	(smi_l2req_strand[1:0]),
				  .smi_l2req_op		(smi_l2req_op[2:0]),
				  .smi_l2req_way		(smi_l2req_way[1:0]),
				  .smi_l2req_address	(smi_l2req_address[25:0]),
				  .smi_l2req_data		(smi_l2req_data[511:0]),
				  .smi_l2req_mask		(smi_l2req_mask[63:0]),
				  .smi_load_buffer_vec	(smi_load_buffer_vec[511:0]),
				  .smi_data_ready	(smi_data_ready),
				  .smi_fill_l2_way	(smi_fill_l2_way[1:0]),
				  .addr_o		(addr_o[31:0]),
				  .request_o		(request_o),
				  .write_o		(write_o),
				  .data_o		(data_o[31:0]),
				  // Inputs
				  .clk			(clk),
				  .rd_l2req_valid		(rd_l2req_valid),
				  .rd_l2req_unit		(rd_l2req_unit[1:0]),
				  .rd_l2req_strand	(rd_l2req_strand[1:0]),
				  .rd_l2req_op		(rd_l2req_op[2:0]),
				  .rd_l2req_way		(rd_l2req_way[1:0]),
				  .rd_l2req_address	(rd_l2req_address[25:0]),
				  .rd_l2req_data		(rd_l2req_data[511:0]),
				  .rd_l2req_mask		(rd_l2req_mask[63:0]),
				  .rd_has_sm_data	(rd_has_sm_data),
				  .rd_replace_l2_way	(rd_replace_l2_way[1:0]),
				  .rd_cache_hit		(rd_cache_hit),
				  .rd_cache_mem_result	(rd_cache_mem_result[511:0]),
				  .rd_old_l2_tag	(rd_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				  .rd_line_is_dirty	(rd_line_is_dirty),
				  .ack_i		(ack_i),
				  .data_i		(data_i[31:0]));
				  
	/////// Performance Counters ////////////////////////////
	reg[63:0] hit_count = 0;
	reg[63:0] miss_count = 0;

	always @(posedge clk)
	begin
		if (dir_l2req_valid && !dir_has_sm_data && (dir_l2req_op == `L2REQ_LOAD
			|| dir_l2req_op == `L2REQ_STORE || dir_l2req_op == `L2REQ_LOAD_SYNC
			|| dir_l2req_op == `L2REQ_STORE_SYNC) && !stall_pipeline)
		begin
			if (dir_cache_hit)		
				hit_count <= #1 hit_count + 1;
			else
				miss_count <= #1 miss_count + 1;
		end
	end
	
	/////////////////////////////////////////////////////////
endmodule
