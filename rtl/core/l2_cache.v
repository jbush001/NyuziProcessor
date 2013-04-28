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
// in a system memory queue, where a state machine transfers data to
// and from system memory.  When a transaction is finished, the packet
// is reissued into the beginning of the pipeline, where it will update 
// the L2 state on its next pass.
//

module l2_cache
	(input                  clk,
	input					reset,

	// L2 Request interface
	input                   l2req_valid,
	input [`CORE_INDEX_WIDTH - 1:0] l2req_core,
	output                  l2req_ready,
	input [1:0]             l2req_unit,
	input [1:0]             l2req_strand,
	input [2:0]             l2req_op,
	input [1:0]             l2req_way,
	input [25:0]            l2req_address,
	input [511:0]           l2req_data,
	input [63:0]            l2req_mask,
	
	// L2 Response Interface
	output                  l2rsp_valid,
	output [`CORE_INDEX_WIDTH - 1:0] l2rsp_core,
	output                  l2rsp_status,
	output [1:0]            l2rsp_unit,
	output [1:0]            l2rsp_strand,
	output [1:0]            l2rsp_op,
	output [`NUM_CORES - 1:0] l2rsp_update,
	output [`NUM_CORES * 2 - 1:0] l2rsp_way,
	output [25:0] 			l2rsp_address,
	output [511:0]          l2rsp_data,
	
	// AXI external memory interface
	output [31:0]			axi_awaddr, 
	output [7:0]			axi_awlen,
	output 					axi_awvalid,
	input					axi_awready,
	output [31:0]			axi_wdata,
	output					axi_wlast,
	output 					axi_wvalid,
	input					axi_wready,
	input					axi_bvalid,
	output					axi_bready,
	output [31:0]			axi_araddr,
	output [7:0]			axi_arlen,
	output 					axi_arvalid,
	input					axi_arready,
	output 					axi_rready, 
	input					axi_rvalid,         
	input [31:0]			axi_rdata,
	
	// To performance counters
	output					pc_event_l2_hit,
	output					pc_event_l2_miss,
	output					pc_event_store);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [511:0]	arb_data_from_memory;	// From l2_cache_arb of l2_cache_arb.v
	wire		arb_is_restarted_request;// From l2_cache_arb of l2_cache_arb.v
	wire [25:0]	arb_l2req_address;	// From l2_cache_arb of l2_cache_arb.v
	wire [`CORE_INDEX_WIDTH-1:0] arb_l2req_core;// From l2_cache_arb of l2_cache_arb.v
	wire [511:0]	arb_l2req_data;		// From l2_cache_arb of l2_cache_arb.v
	wire [63:0]	arb_l2req_mask;		// From l2_cache_arb of l2_cache_arb.v
	wire [2:0]	arb_l2req_op;		// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_l2req_strand;	// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_l2req_unit;		// From l2_cache_arb of l2_cache_arb.v
	wire		arb_l2req_valid;	// From l2_cache_arb of l2_cache_arb.v
	wire [1:0]	arb_l2req_way;		// From l2_cache_arb of l2_cache_arb.v
	wire		bif_data_ready;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire		bif_duplicate_request;	// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire		bif_input_wait;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [25:0]	bif_l2req_address;	// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [`CORE_INDEX_WIDTH-1:0] bif_l2req_core;// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [511:0]	bif_l2req_data;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [63:0]	bif_l2req_mask;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [2:0]	bif_l2req_op;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [1:0]	bif_l2req_strand;	// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [1:0]	bif_l2req_unit;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [1:0]	bif_l2req_way;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [511:0]	bif_load_buffer_vec;	// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire		dir_cache_hit;		// From l2_cache_dir of l2_cache_dir.v
	wire [511:0]	dir_data_from_memory;	// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_hit_l2_way;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_is_l2_fill;		// From l2_cache_dir of l2_cache_dir.v
	wire [`NUM_CORES-1:0] dir_l1_has_line;	// From l2_cache_dir of l2_cache_dir.v
	wire [`NUM_CORES*2-1:0] dir_l1_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2_dirty0;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2_dirty1;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2_dirty2;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2_dirty3;		// From l2_cache_dir of l2_cache_dir.v
	wire [25:0]	dir_l2req_address;	// From l2_cache_dir of l2_cache_dir.v
	wire [`CORE_INDEX_WIDTH-1:0] dir_l2req_core;// From l2_cache_dir of l2_cache_dir.v
	wire [511:0]	dir_l2req_data;		// From l2_cache_dir of l2_cache_dir.v
	wire [63:0]	dir_l2req_mask;		// From l2_cache_dir of l2_cache_dir.v
	wire [2:0]	dir_l2req_op;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_l2req_strand;	// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_l2req_unit;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_l2req_valid;	// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_l2req_way;		// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_miss_fill_l2_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_new_dirty;		// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_TAG_WIDTH-1:0] dir_old_l2_tag;// From l2_cache_dir of l2_cache_dir.v
	wire [`CORE_INDEX_WIDTH-1:0] dir_update_dir_core;// From l2_cache_dir of l2_cache_dir.v
	wire [`L1_SET_INDEX_WIDTH-1:0] dir_update_dir_set;// From l2_cache_dir of l2_cache_dir.v
	wire [`L1_TAG_WIDTH-1:0] dir_update_dir_tag;// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_dir_valid;	// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_update_dir_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_directory;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_dirty0;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_dirty1;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_dirty2;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_dirty3;	// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_SET_INDEX_WIDTH-1:0] dir_update_dirty_set;// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_tag_enable;	// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_SET_INDEX_WIDTH-1:0] dir_update_tag_set;// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_TAG_WIDTH-1:0] dir_update_tag_tag;// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_tag_valid;	// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_update_tag_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		rd_cache_hit;		// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_cache_mem_result;	// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_data_from_memory;	// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES*2-1:0] rd_dir_l1_way;	// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_hit_l2_way;		// From l2_cache_read of l2_cache_read.v
	wire		rd_is_l2_fill;		// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES-1:0] rd_l1_has_line;	// From l2_cache_read of l2_cache_read.v
	wire [25:0]	rd_l2req_address;	// From l2_cache_read of l2_cache_read.v
	wire [`CORE_INDEX_WIDTH-1:0] rd_l2req_core;// From l2_cache_read of l2_cache_read.v
	wire [511:0]	rd_l2req_data;		// From l2_cache_read of l2_cache_read.v
	wire [63:0]	rd_l2req_mask;		// From l2_cache_read of l2_cache_read.v
	wire [2:0]	rd_l2req_op;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_l2req_strand;	// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_l2req_unit;		// From l2_cache_read of l2_cache_read.v
	wire		rd_l2req_valid;		// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_l2req_way;		// From l2_cache_read of l2_cache_read.v
	wire		rd_line_is_dirty;	// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_miss_fill_l2_way;	// From l2_cache_read of l2_cache_read.v
	wire [`L2_TAG_WIDTH-1:0] rd_old_l2_tag;	// From l2_cache_read of l2_cache_read.v
	wire		rd_store_sync_success;	// From l2_cache_read of l2_cache_read.v
	wire [511:0]	tag_data_from_memory;	// From l2_cache_tag of l2_cache_tag.v
	wire		tag_is_restarted_request;// From l2_cache_tag of l2_cache_tag.v
	wire [`NUM_CORES-1:0] tag_l1_has_line;	// From l2_cache_tag of l2_cache_tag.v
	wire [`NUM_CORES*2-1:0] tag_l1_way;	// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_dirty0;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_dirty1;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_dirty2;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_dirty3;		// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_l2_tag0;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_l2_tag1;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_l2_tag2;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH-1:0] tag_l2_tag3;	// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_valid0;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_valid1;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_valid2;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2_valid3;		// From l2_cache_tag of l2_cache_tag.v
	wire [25:0]	tag_l2req_address;	// From l2_cache_tag of l2_cache_tag.v
	wire [`CORE_INDEX_WIDTH-1:0] tag_l2req_core;// From l2_cache_tag of l2_cache_tag.v
	wire [511:0]	tag_l2req_data;		// From l2_cache_tag of l2_cache_tag.v
	wire [63:0]	tag_l2req_mask;		// From l2_cache_tag of l2_cache_tag.v
	wire [2:0]	tag_l2req_op;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_l2req_strand;	// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_l2req_unit;		// From l2_cache_tag of l2_cache_tag.v
	wire		tag_l2req_valid;	// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_l2req_way;		// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_miss_fill_l2_way;	// From l2_cache_tag of l2_cache_tag.v
	wire		wr_cache_hit;		// From l2_cache_write of l2_cache_write.v
	wire [`L2_CACHE_ADDR_WIDTH-1:0] wr_cache_write_index;// From l2_cache_write of l2_cache_write.v
	wire [511:0]	wr_data;		// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES*2-1:0] wr_dir_l1_way;	// From l2_cache_write of l2_cache_write.v
	wire		wr_is_l2_fill;		// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES-1:0] wr_l1_has_line;	// From l2_cache_write of l2_cache_write.v
	wire [25:0]	wr_l2req_address;	// From l2_cache_write of l2_cache_write.v
	wire [`CORE_INDEX_WIDTH-1:0] wr_l2req_core;// From l2_cache_write of l2_cache_write.v
	wire [2:0]	wr_l2req_op;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_l2req_strand;	// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_l2req_unit;		// From l2_cache_write of l2_cache_write.v
	wire		wr_l2req_valid;		// From l2_cache_write of l2_cache_write.v
	wire [1:0]	wr_l2req_way;		// From l2_cache_write of l2_cache_write.v
	wire		wr_store_sync_success;	// From l2_cache_write of l2_cache_write.v
	wire [511:0]	wr_update_data;		// From l2_cache_write of l2_cache_write.v
	wire		wr_update_enable;	// From l2_cache_write of l2_cache_write.v
	// End of automatics
	
	// Currently not used, but will be necessary when l2_cache_response needs to
	// send message to multiple cores
	wire stall_pipeline = 0;

	l2_cache_arb l2_cache_arb(/*AUTOINST*/
				  // Outputs
				  .l2req_ready		(l2req_ready),
				  .arb_l2req_valid	(arb_l2req_valid),
				  .arb_l2req_core	(arb_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				  .arb_l2req_unit	(arb_l2req_unit[1:0]),
				  .arb_l2req_strand	(arb_l2req_strand[1:0]),
				  .arb_l2req_op		(arb_l2req_op[2:0]),
				  .arb_l2req_way	(arb_l2req_way[1:0]),
				  .arb_l2req_address	(arb_l2req_address[25:0]),
				  .arb_l2req_data	(arb_l2req_data[511:0]),
				  .arb_l2req_mask	(arb_l2req_mask[63:0]),
				  .arb_is_restarted_request(arb_is_restarted_request),
				  .arb_data_from_memory	(arb_data_from_memory[511:0]),
				  // Inputs
				  .clk			(clk),
				  .reset		(reset),
				  .stall_pipeline	(stall_pipeline),
				  .l2req_valid		(l2req_valid),
				  .l2req_core		(l2req_core[`CORE_INDEX_WIDTH-1:0]),
				  .l2req_unit		(l2req_unit[1:0]),
				  .l2req_strand		(l2req_strand[1:0]),
				  .l2req_op		(l2req_op[2:0]),
				  .l2req_way		(l2req_way[1:0]),
				  .l2req_address	(l2req_address[25:0]),
				  .l2req_data		(l2req_data[511:0]),
				  .l2req_mask		(l2req_mask[63:0]),
				  .bif_input_wait	(bif_input_wait),
				  .bif_l2req_core	(bif_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				  .bif_l2req_unit	(bif_l2req_unit[1:0]),
				  .bif_l2req_strand	(bif_l2req_strand[1:0]),
				  .bif_l2req_op		(bif_l2req_op[2:0]),
				  .bif_l2req_way	(bif_l2req_way[1:0]),
				  .bif_l2req_address	(bif_l2req_address[25:0]),
				  .bif_l2req_data	(bif_l2req_data[511:0]),
				  .bif_l2req_mask	(bif_l2req_mask[63:0]),
				  .bif_load_buffer_vec	(bif_load_buffer_vec[511:0]),
				  .bif_data_ready	(bif_data_ready),
				  .bif_duplicate_request(bif_duplicate_request));

	l2_cache_tag l2_cache_tag  (/*AUTOINST*/
				    // Outputs
				    .tag_l2req_valid	(tag_l2req_valid),
				    .tag_l2req_core	(tag_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				    .tag_l2req_unit	(tag_l2req_unit[1:0]),
				    .tag_l2req_strand	(tag_l2req_strand[1:0]),
				    .tag_l2req_op	(tag_l2req_op[2:0]),
				    .tag_l2req_way	(tag_l2req_way[1:0]),
				    .tag_l2req_address	(tag_l2req_address[25:0]),
				    .tag_l2req_data	(tag_l2req_data[511:0]),
				    .tag_l2req_mask	(tag_l2req_mask[63:0]),
				    .tag_is_restarted_request(tag_is_restarted_request),
				    .tag_data_from_memory(tag_data_from_memory[511:0]),
				    .tag_miss_fill_l2_way(tag_miss_fill_l2_way[1:0]),
				    .tag_l2_tag0	(tag_l2_tag0[`L2_TAG_WIDTH-1:0]),
				    .tag_l2_tag1	(tag_l2_tag1[`L2_TAG_WIDTH-1:0]),
				    .tag_l2_tag2	(tag_l2_tag2[`L2_TAG_WIDTH-1:0]),
				    .tag_l2_tag3	(tag_l2_tag3[`L2_TAG_WIDTH-1:0]),
				    .tag_l2_valid0	(tag_l2_valid0),
				    .tag_l2_valid1	(tag_l2_valid1),
				    .tag_l2_valid2	(tag_l2_valid2),
				    .tag_l2_valid3	(tag_l2_valid3),
				    .tag_l2_dirty0	(tag_l2_dirty0),
				    .tag_l2_dirty1	(tag_l2_dirty1),
				    .tag_l2_dirty2	(tag_l2_dirty2),
				    .tag_l2_dirty3	(tag_l2_dirty3),
				    .tag_l1_has_line	(tag_l1_has_line[`NUM_CORES-1:0]),
				    .tag_l1_way		(tag_l1_way[`NUM_CORES*2-1:0]),
				    .pc_event_store	(pc_event_store),
				    // Inputs
				    .clk		(clk),
				    .reset		(reset),
				    .stall_pipeline	(stall_pipeline),
				    .arb_l2req_valid	(arb_l2req_valid),
				    .arb_l2req_core	(arb_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				    .arb_l2req_unit	(arb_l2req_unit[1:0]),
				    .arb_l2req_strand	(arb_l2req_strand[1:0]),
				    .arb_l2req_op	(arb_l2req_op[2:0]),
				    .arb_l2req_way	(arb_l2req_way[1:0]),
				    .arb_l2req_address	(arb_l2req_address[25:0]),
				    .arb_l2req_data	(arb_l2req_data[511:0]),
				    .arb_l2req_mask	(arb_l2req_mask[63:0]),
				    .arb_is_restarted_request(arb_is_restarted_request),
				    .arb_data_from_memory(arb_data_from_memory[511:0]),
				    .dir_update_tag_enable(dir_update_tag_enable),
				    .dir_update_tag_valid(dir_update_tag_valid),
				    .dir_update_tag_tag	(dir_update_tag_tag[`L2_TAG_WIDTH-1:0]),
				    .dir_update_tag_set	(dir_update_tag_set[`L2_SET_INDEX_WIDTH-1:0]),
				    .dir_update_tag_way	(dir_update_tag_way[1:0]),
				    .dir_update_dirty_set(dir_update_dirty_set[`L2_SET_INDEX_WIDTH-1:0]),
				    .dir_new_dirty	(dir_new_dirty),
				    .dir_update_dirty0	(dir_update_dirty0),
				    .dir_update_dirty1	(dir_update_dirty1),
				    .dir_update_dirty2	(dir_update_dirty2),
				    .dir_update_dirty3	(dir_update_dirty3),
				    .dir_update_dir_core(dir_update_dir_core[`CORE_INDEX_WIDTH-1:0]),
				    .dir_update_directory(dir_update_directory),
				    .dir_update_dir_valid(dir_update_dir_valid),
				    .dir_update_dir_way	(dir_update_dir_way[1:0]),
				    .dir_update_dir_tag	(dir_update_dir_tag[`L1_TAG_WIDTH-1:0]),
				    .dir_update_dir_set	(dir_update_dir_set[`L1_SET_INDEX_WIDTH-1:0]),
				    .dir_hit_l2_way	(dir_hit_l2_way[1:0]));

	l2_cache_dir l2_cache_dir(/*AUTOINST*/
				  // Outputs
				  .dir_l2req_valid	(dir_l2req_valid),
				  .dir_l2req_core	(dir_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				  .dir_l2req_unit	(dir_l2req_unit[1:0]),
				  .dir_l2req_strand	(dir_l2req_strand[1:0]),
				  .dir_l2req_op		(dir_l2req_op[2:0]),
				  .dir_l2req_way	(dir_l2req_way[1:0]),
				  .dir_l2req_address	(dir_l2req_address[25:0]),
				  .dir_l2req_data	(dir_l2req_data[511:0]),
				  .dir_l2req_mask	(dir_l2req_mask[63:0]),
				  .dir_is_l2_fill	(dir_is_l2_fill),
				  .dir_data_from_memory	(dir_data_from_memory[511:0]),
				  .dir_miss_fill_l2_way	(dir_miss_fill_l2_way[1:0]),
				  .dir_hit_l2_way	(dir_hit_l2_way[1:0]),
				  .dir_cache_hit	(dir_cache_hit),
				  .dir_old_l2_tag	(dir_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				  .dir_l1_has_line	(dir_l1_has_line[`NUM_CORES-1:0]),
				  .dir_l1_way		(dir_l1_way[`NUM_CORES*2-1:0]),
				  .dir_l2_dirty0	(dir_l2_dirty0),
				  .dir_l2_dirty1	(dir_l2_dirty1),
				  .dir_l2_dirty2	(dir_l2_dirty2),
				  .dir_l2_dirty3	(dir_l2_dirty3),
				  .dir_update_tag_enable(dir_update_tag_enable),
				  .dir_update_tag_valid	(dir_update_tag_valid),
				  .dir_update_tag_tag	(dir_update_tag_tag[`L2_TAG_WIDTH-1:0]),
				  .dir_update_tag_set	(dir_update_tag_set[`L2_SET_INDEX_WIDTH-1:0]),
				  .dir_update_tag_way	(dir_update_tag_way[1:0]),
				  .dir_update_dirty_set	(dir_update_dirty_set[`L2_SET_INDEX_WIDTH-1:0]),
				  .dir_new_dirty	(dir_new_dirty),
				  .dir_update_dirty0	(dir_update_dirty0),
				  .dir_update_dirty1	(dir_update_dirty1),
				  .dir_update_dirty2	(dir_update_dirty2),
				  .dir_update_dirty3	(dir_update_dirty3),
				  .dir_update_directory	(dir_update_directory),
				  .dir_update_dir_way	(dir_update_dir_way[1:0]),
				  .dir_update_dir_tag	(dir_update_dir_tag[`L1_TAG_WIDTH-1:0]),
				  .dir_update_dir_valid	(dir_update_dir_valid),
				  .dir_update_dir_core	(dir_update_dir_core[`CORE_INDEX_WIDTH-1:0]),
				  .dir_update_dir_set	(dir_update_dir_set[`L1_SET_INDEX_WIDTH-1:0]),
				  .pc_event_l2_hit	(pc_event_l2_hit),
				  .pc_event_l2_miss	(pc_event_l2_miss),
				  // Inputs
				  .clk			(clk),
				  .reset		(reset),
				  .stall_pipeline	(stall_pipeline),
				  .tag_l2req_valid	(tag_l2req_valid),
				  .tag_l2req_core	(tag_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				  .tag_l2req_unit	(tag_l2req_unit[1:0]),
				  .tag_l2req_strand	(tag_l2req_strand[1:0]),
				  .tag_l2req_op		(tag_l2req_op[2:0]),
				  .tag_l2req_way	(tag_l2req_way[1:0]),
				  .tag_l2req_address	(tag_l2req_address[25:0]),
				  .tag_l2req_data	(tag_l2req_data[511:0]),
				  .tag_l2req_mask	(tag_l2req_mask[63:0]),
				  .tag_is_restarted_request(tag_is_restarted_request),
				  .tag_data_from_memory	(tag_data_from_memory[511:0]),
				  .tag_miss_fill_l2_way	(tag_miss_fill_l2_way[1:0]),
				  .tag_l2_tag0		(tag_l2_tag0[`L2_TAG_WIDTH-1:0]),
				  .tag_l2_tag1		(tag_l2_tag1[`L2_TAG_WIDTH-1:0]),
				  .tag_l2_tag2		(tag_l2_tag2[`L2_TAG_WIDTH-1:0]),
				  .tag_l2_tag3		(tag_l2_tag3[`L2_TAG_WIDTH-1:0]),
				  .tag_l2_valid0	(tag_l2_valid0),
				  .tag_l2_valid1	(tag_l2_valid1),
				  .tag_l2_valid2	(tag_l2_valid2),
				  .tag_l2_valid3	(tag_l2_valid3),
				  .tag_l1_has_line	(tag_l1_has_line[`NUM_CORES-1:0]),
				  .tag_l1_way		(tag_l1_way[`NUM_CORES*2-1:0]),
				  .tag_l2_dirty0	(tag_l2_dirty0),
				  .tag_l2_dirty1	(tag_l2_dirty1),
				  .tag_l2_dirty2	(tag_l2_dirty2),
				  .tag_l2_dirty3	(tag_l2_dirty3));

	l2_cache_read l2_cache_read(/*AUTOINST*/
				    // Outputs
				    .rd_l2req_valid	(rd_l2req_valid),
				    .rd_l2req_core	(rd_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				    .rd_l2req_unit	(rd_l2req_unit[1:0]),
				    .rd_l2req_strand	(rd_l2req_strand[1:0]),
				    .rd_l2req_op	(rd_l2req_op[2:0]),
				    .rd_l2req_way	(rd_l2req_way[1:0]),
				    .rd_l2req_address	(rd_l2req_address[25:0]),
				    .rd_l2req_data	(rd_l2req_data[511:0]),
				    .rd_l2req_mask	(rd_l2req_mask[63:0]),
				    .rd_is_l2_fill	(rd_is_l2_fill),
				    .rd_data_from_memory(rd_data_from_memory[511:0]),
				    .rd_miss_fill_l2_way(rd_miss_fill_l2_way[1:0]),
				    .rd_hit_l2_way	(rd_hit_l2_way[1:0]),
				    .rd_cache_hit	(rd_cache_hit),
				    .rd_l1_has_line	(rd_l1_has_line[`NUM_CORES-1:0]),
				    .rd_dir_l1_way	(rd_dir_l1_way[`NUM_CORES*2-1:0]),
				    .rd_cache_mem_result(rd_cache_mem_result[511:0]),
				    .rd_old_l2_tag	(rd_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				    .rd_line_is_dirty	(rd_line_is_dirty),
				    .rd_store_sync_success(rd_store_sync_success),
				    // Inputs
				    .clk		(clk),
				    .reset		(reset),
				    .stall_pipeline	(stall_pipeline),
				    .dir_l2req_core	(dir_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				    .dir_l2req_valid	(dir_l2req_valid),
				    .dir_l2req_unit	(dir_l2req_unit[1:0]),
				    .dir_l2req_strand	(dir_l2req_strand[1:0]),
				    .dir_l2req_op	(dir_l2req_op[2:0]),
				    .dir_l2req_way	(dir_l2req_way[1:0]),
				    .dir_l2req_address	(dir_l2req_address[25:0]),
				    .dir_l2req_data	(dir_l2req_data[511:0]),
				    .dir_l2req_mask	(dir_l2req_mask[63:0]),
				    .dir_is_l2_fill	(dir_is_l2_fill),
				    .dir_data_from_memory(dir_data_from_memory[511:0]),
				    .dir_hit_l2_way	(dir_hit_l2_way[1:0]),
				    .dir_cache_hit	(dir_cache_hit),
				    .dir_old_l2_tag	(dir_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				    .dir_l1_has_line	(dir_l1_has_line[`NUM_CORES-1:0]),
				    .dir_l1_way		(dir_l1_way[`NUM_CORES*2-1:0]),
				    .dir_l2_dirty0	(dir_l2_dirty0),
				    .dir_l2_dirty1	(dir_l2_dirty1),
				    .dir_l2_dirty2	(dir_l2_dirty2),
				    .dir_l2_dirty3	(dir_l2_dirty3),
				    .dir_miss_fill_l2_way(dir_miss_fill_l2_way[1:0]),
				    .wr_update_enable	(wr_update_enable),
				    .wr_cache_write_index(wr_cache_write_index[`L2_CACHE_ADDR_WIDTH-1:0]),
				    .wr_update_data	(wr_update_data[511:0]));

	l2_cache_write l2_cache_write(/*AUTOINST*/
				      // Outputs
				      .wr_l2req_valid	(wr_l2req_valid),
				      .wr_l2req_core	(wr_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				      .wr_l2req_unit	(wr_l2req_unit[1:0]),
				      .wr_l2req_strand	(wr_l2req_strand[1:0]),
				      .wr_l2req_op	(wr_l2req_op[2:0]),
				      .wr_l2req_way	(wr_l2req_way[1:0]),
				      .wr_l2req_address	(wr_l2req_address[25:0]),
				      .wr_cache_hit	(wr_cache_hit),
				      .wr_data		(wr_data[511:0]),
				      .wr_l1_has_line	(wr_l1_has_line[`NUM_CORES-1:0]),
				      .wr_dir_l1_way	(wr_dir_l1_way[`NUM_CORES*2-1:0]),
				      .wr_is_l2_fill	(wr_is_l2_fill),
				      .wr_update_enable	(wr_update_enable),
				      .wr_cache_write_index(wr_cache_write_index[`L2_CACHE_ADDR_WIDTH-1:0]),
				      .wr_update_data	(wr_update_data[511:0]),
				      .wr_store_sync_success(wr_store_sync_success),
				      // Inputs
				      .clk		(clk),
				      .reset		(reset),
				      .stall_pipeline	(stall_pipeline),
				      .rd_l2req_valid	(rd_l2req_valid),
				      .rd_l2req_core	(rd_l2req_core[`CORE_INDEX_WIDTH-1:0]),
				      .rd_l2req_unit	(rd_l2req_unit[1:0]),
				      .rd_l2req_strand	(rd_l2req_strand[1:0]),
				      .rd_l2req_op	(rd_l2req_op[2:0]),
				      .rd_l2req_way	(rd_l2req_way[1:0]),
				      .rd_l2req_address	(rd_l2req_address[25:0]),
				      .rd_l2req_data	(rd_l2req_data[511:0]),
				      .rd_l2req_mask	(rd_l2req_mask[63:0]),
				      .rd_is_l2_fill	(rd_is_l2_fill),
				      .rd_data_from_memory(rd_data_from_memory[511:0]),
				      .rd_hit_l2_way	(rd_hit_l2_way[1:0]),
				      .rd_cache_hit	(rd_cache_hit),
				      .rd_l1_has_line	(rd_l1_has_line[`NUM_CORES-1:0]),
				      .rd_dir_l1_way	(rd_dir_l1_way[`NUM_CORES*2-1:0]),
				      .rd_cache_mem_result(rd_cache_mem_result[511:0]),
				      .rd_miss_fill_l2_way(rd_miss_fill_l2_way[1:0]),
				      .rd_store_sync_success(rd_store_sync_success));

	l2_cache_response l2_cache_response(/*AUTOINST*/
					    // Outputs
					    .l2rsp_valid	(l2rsp_valid),
					    .l2rsp_status	(l2rsp_status),
					    .l2rsp_core		(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
					    .l2rsp_unit		(l2rsp_unit[1:0]),
					    .l2rsp_strand	(l2rsp_strand[1:0]),
					    .l2rsp_op		(l2rsp_op[1:0]),
					    .l2rsp_update	(l2rsp_update[`NUM_CORES-1:0]),
					    .l2rsp_way		(l2rsp_way[`NUM_CORES*2-1:0]),
					    .l2rsp_address	(l2rsp_address[25:0]),
					    .l2rsp_data		(l2rsp_data[511:0]),
					    // Inputs
					    .clk		(clk),
					    .reset		(reset),
					    .wr_l2req_valid	(wr_l2req_valid),
					    .wr_l2req_core	(wr_l2req_core[`CORE_INDEX_WIDTH-1:0]),
					    .wr_l2req_unit	(wr_l2req_unit[1:0]),
					    .wr_l2req_strand	(wr_l2req_strand[1:0]),
					    .wr_l2req_op	(wr_l2req_op[2:0]),
					    .wr_l2req_way	(wr_l2req_way[1:0]),
					    .wr_data		(wr_data[511:0]),
					    .wr_l1_has_line	(wr_l1_has_line[`NUM_CORES-1:0]),
					    .wr_dir_l1_way	(wr_dir_l1_way[`NUM_CORES*2-1:0]),
					    .wr_cache_hit	(wr_cache_hit),
					    .wr_l2req_address	(wr_l2req_address[25:0]),
					    .wr_is_l2_fill	(wr_is_l2_fill),
					    .wr_store_sync_success(wr_store_sync_success));

	l2_cache_bus_interface l2_cache_bus_interface(/*AUTOINST*/
						      // Outputs
						      .bif_input_wait	(bif_input_wait),
						      .bif_duplicate_request(bif_duplicate_request),
						      .bif_l2req_core	(bif_l2req_core[`CORE_INDEX_WIDTH-1:0]),
						      .bif_l2req_unit	(bif_l2req_unit[1:0]),
						      .bif_l2req_strand	(bif_l2req_strand[1:0]),
						      .bif_l2req_op	(bif_l2req_op[2:0]),
						      .bif_l2req_way	(bif_l2req_way[1:0]),
						      .bif_l2req_address(bif_l2req_address[25:0]),
						      .bif_l2req_data	(bif_l2req_data[511:0]),
						      .bif_l2req_mask	(bif_l2req_mask[63:0]),
						      .bif_load_buffer_vec(bif_load_buffer_vec[511:0]),
						      .bif_data_ready	(bif_data_ready),
						      .axi_awaddr	(axi_awaddr[31:0]),
						      .axi_awlen	(axi_awlen[7:0]),
						      .axi_awvalid	(axi_awvalid),
						      .axi_wdata	(axi_wdata[31:0]),
						      .axi_wlast	(axi_wlast),
						      .axi_wvalid	(axi_wvalid),
						      .axi_bready	(axi_bready),
						      .axi_araddr	(axi_araddr[31:0]),
						      .axi_arlen	(axi_arlen[7:0]),
						      .axi_arvalid	(axi_arvalid),
						      .axi_rready	(axi_rready),
						      // Inputs
						      .clk		(clk),
						      .reset		(reset),
						      .rd_l2req_valid	(rd_l2req_valid),
						      .rd_l2req_core	(rd_l2req_core[`CORE_INDEX_WIDTH-1:0]),
						      .rd_l2req_unit	(rd_l2req_unit[1:0]),
						      .rd_l2req_strand	(rd_l2req_strand[1:0]),
						      .rd_l2req_op	(rd_l2req_op[2:0]),
						      .rd_l2req_way	(rd_l2req_way[1:0]),
						      .rd_l2req_address	(rd_l2req_address[25:0]),
						      .rd_l2req_data	(rd_l2req_data[511:0]),
						      .rd_l2req_mask	(rd_l2req_mask[63:0]),
						      .rd_is_l2_fill	(rd_is_l2_fill),
						      .rd_cache_hit	(rd_cache_hit),
						      .rd_cache_mem_result(rd_cache_mem_result[511:0]),
						      .rd_old_l2_tag	(rd_old_l2_tag[`L2_TAG_WIDTH-1:0]),
						      .rd_line_is_dirty	(rd_line_is_dirty),
						      .axi_awready	(axi_awready),
						      .axi_wready	(axi_wready),
						      .axi_bvalid	(axi_bvalid),
						      .axi_arready	(axi_arready),
						      .axi_rvalid	(axi_rvalid),
						      .axi_rdata	(axi_rdata[31:0]));
endmodule
