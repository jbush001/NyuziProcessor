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

`include "defines.v"

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
	#(parameter AXI_DATA_WIDTH = 32)
	(input                               clk,
	input                                reset,

	// L2 Request interface
	input l2req_packet_t                 l2req_packet,
	output                               l2req_ready,
	
	// L2 Response Interface
	output l2rsp_packet_t                l2rsp_packet,
	
	// AXI external memory interface
	output [31:0]                        axi_awaddr, 
	output [7:0]                         axi_awlen,
	output                               axi_awvalid,
	input                                axi_awready,
	output [31:0]                        axi_wdata,
	output                               axi_wlast,
	output                               axi_wvalid,
	input                                axi_wready,
	input                                axi_bvalid,
	output                               axi_bready,
	output [31:0]                        axi_araddr,
	output [7:0]                         axi_arlen,
	output                               axi_arvalid,
	input                                axi_arready,
	output                               axi_rready, 
	input                                axi_rvalid,         
	input [31:0]                         axi_rdata,
	
	// To performance counters
	output                               pc_event_l2_hit,
	output                               pc_event_l2_miss,
	output                               pc_event_store,
	output                               pc_event_l2_wait,
	output                               pc_event_l2_writeback);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [`CACHE_LINE_BITS-1:0] arb_data_from_memory;// From l2_cache_arb of l2_cache_arb.v
	wire		arb_is_restarted_request;// From l2_cache_arb of l2_cache_arb.v
	wire		bif_data_ready;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire		bif_duplicate_request;	// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire		bif_input_wait;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [`CACHE_LINE_BITS-1:0] bif_load_buffer_vec;// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire		dir_cache_hit;		// From l2_cache_dir of l2_cache_dir.v
	wire [`CACHE_LINE_BITS-1:0] dir_data_from_memory;// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_hit_l2_way;		// From l2_cache_dir of l2_cache_dir.v
	wire		dir_is_l2_fill;		// From l2_cache_dir of l2_cache_dir.v
	wire [`NUM_CORES-1:0] dir_l1_has_line;	// From l2_cache_dir of l2_cache_dir.v
	wire [`NUM_CORES*2-1:0] dir_l1_way;	// From l2_cache_dir of l2_cache_dir.v
	wire [`STRANDS_PER_CORE-1:0] dir_l2_dirty;// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_miss_fill_l2_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_new_dirty;		// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_TAG_WIDTH-1:0] dir_old_l2_tag;// From l2_cache_dir of l2_cache_dir.v
	wire [`CORE_INDEX_WIDTH-1:0] dir_update_dir_core;// From l2_cache_dir of l2_cache_dir.v
	wire [`L1_SET_INDEX_WIDTH-1:0] dir_update_dir_set;// From l2_cache_dir of l2_cache_dir.v
	wire [`L1_TAG_WIDTH-1:0] dir_update_dir_tag;// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_dir_valid;	// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_update_dir_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_directory;	// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_NUM_WAYS-1:0] dir_update_dirty;// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_SET_INDEX_WIDTH-1:0] dir_update_dirty_set;// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_tag_enable;	// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_SET_INDEX_WIDTH-1:0] dir_update_tag_set;// From l2_cache_dir of l2_cache_dir.v
	wire [`L2_TAG_WIDTH-1:0] dir_update_tag_tag;// From l2_cache_dir of l2_cache_dir.v
	wire		dir_update_tag_valid;	// From l2_cache_dir of l2_cache_dir.v
	wire [1:0]	dir_update_tag_way;	// From l2_cache_dir of l2_cache_dir.v
	wire		rd_cache_hit;		// From l2_cache_read of l2_cache_read.v
	wire [`CACHE_LINE_BITS-1:0] rd_cache_mem_result;// From l2_cache_read of l2_cache_read.v
	wire [`CACHE_LINE_BITS-1:0] rd_data_from_memory;// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES*2-1:0] rd_dir_l1_way;	// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_hit_l2_way;		// From l2_cache_read of l2_cache_read.v
	wire		rd_is_l2_fill;		// From l2_cache_read of l2_cache_read.v
	wire [`NUM_CORES-1:0] rd_l1_has_line;	// From l2_cache_read of l2_cache_read.v
	wire		rd_line_is_dirty;	// From l2_cache_read of l2_cache_read.v
	wire [1:0]	rd_miss_fill_l2_way;	// From l2_cache_read of l2_cache_read.v
	wire [`L2_TAG_WIDTH-1:0] rd_old_l2_tag;	// From l2_cache_read of l2_cache_read.v
	wire		rd_store_sync_success;	// From l2_cache_read of l2_cache_read.v
	wire [`CACHE_LINE_BITS-1:0] tag_data_from_memory;// From l2_cache_tag of l2_cache_tag.v
	wire		tag_is_restarted_request;// From l2_cache_tag of l2_cache_tag.v
	wire [`NUM_CORES-1:0] tag_l1_has_line;	// From l2_cache_tag of l2_cache_tag.v
	wire [`NUM_CORES*2-1:0] tag_l1_way;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_NUM_WAYS-1:0] tag_l2_dirty;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH*`L2_NUM_WAYS-1:0] tag_l2_tag;// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_NUM_WAYS-1:0] tag_l2_valid;	// From l2_cache_tag of l2_cache_tag.v
	wire [1:0]	tag_miss_fill_l2_way;	// From l2_cache_tag of l2_cache_tag.v
	wire		wr_cache_hit;		// From l2_cache_write of l2_cache_write.v
	wire [`L2_CACHE_ADDR_WIDTH-1:0] wr_cache_write_index;// From l2_cache_write of l2_cache_write.v
	wire [`CACHE_LINE_BITS-1:0] wr_data;	// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES*2-1:0] wr_dir_l1_way;	// From l2_cache_write of l2_cache_write.v
	wire		wr_is_l2_fill;		// From l2_cache_write of l2_cache_write.v
	wire [`NUM_CORES-1:0] wr_l1_has_line;	// From l2_cache_write of l2_cache_write.v
	wire		wr_store_sync_success;	// From l2_cache_write of l2_cache_write.v
	wire [`CACHE_LINE_BITS-1:0] wr_update_data;// From l2_cache_write of l2_cache_write.v
	wire		wr_update_enable;	// From l2_cache_write of l2_cache_write.v
	// End of automatics
	
	l2req_packet_t arb_l2req_packet;
	l2req_packet_t bif_l2req_packet;
	l2req_packet_t tag_l2req_packet;
	l2req_packet_t dir_l2req_packet;
	l2req_packet_t rd_l2req_packet;
	l2req_packet_t wr_l2req_packet;
	
	
	assign pc_event_l2_wait = l2req_packet.valid && !l2req_ready;
	
	l2_cache_arb l2_cache_arb(/*AUTOINST*/
				  // Interfaces
				  .l2req_packet		(l2req_packet),
				  .bif_l2req_packet	(bif_l2req_packet),
				  .arb_l2req_packet	(arb_l2req_packet),
				  // Outputs
				  .l2req_ready		(l2req_ready),
				  .arb_is_restarted_request(arb_is_restarted_request),
				  .arb_data_from_memory	(arb_data_from_memory[`CACHE_LINE_BITS-1:0]),
				  // Inputs
				  .clk			(clk),
				  .reset		(reset),
				  .bif_input_wait	(bif_input_wait),
				  .bif_load_buffer_vec	(bif_load_buffer_vec[`CACHE_LINE_BITS-1:0]),
				  .bif_data_ready	(bif_data_ready),
				  .bif_duplicate_request(bif_duplicate_request));

	l2_cache_tag l2_cache_tag  (/*AUTOINST*/
				    // Interfaces
				    .arb_l2req_packet	(arb_l2req_packet),
				    .tag_l2req_packet	(tag_l2req_packet),
				    // Outputs
				    .tag_is_restarted_request(tag_is_restarted_request),
				    .tag_data_from_memory(tag_data_from_memory[`CACHE_LINE_BITS-1:0]),
				    .tag_miss_fill_l2_way(tag_miss_fill_l2_way[1:0]),
				    .tag_l2_tag		(tag_l2_tag[`L2_TAG_WIDTH*`L2_NUM_WAYS-1:0]),
				    .tag_l2_valid	(tag_l2_valid[`L2_NUM_WAYS-1:0]),
				    .tag_l2_dirty	(tag_l2_dirty[`L2_NUM_WAYS-1:0]),
				    .tag_l1_has_line	(tag_l1_has_line[`NUM_CORES-1:0]),
				    .tag_l1_way		(tag_l1_way[`NUM_CORES*2-1:0]),
				    .pc_event_store	(pc_event_store),
				    // Inputs
				    .clk		(clk),
				    .reset		(reset),
				    .arb_is_restarted_request(arb_is_restarted_request),
				    .arb_data_from_memory(arb_data_from_memory[`CACHE_LINE_BITS-1:0]),
				    .dir_update_tag_enable(dir_update_tag_enable),
				    .dir_update_tag_valid(dir_update_tag_valid),
				    .dir_update_tag_tag	(dir_update_tag_tag[`L2_TAG_WIDTH-1:0]),
				    .dir_update_tag_set	(dir_update_tag_set[`L2_SET_INDEX_WIDTH-1:0]),
				    .dir_update_tag_way	(dir_update_tag_way[1:0]),
				    .dir_update_dirty_set(dir_update_dirty_set[`L2_SET_INDEX_WIDTH-1:0]),
				    .dir_new_dirty	(dir_new_dirty),
				    .dir_update_dirty	(dir_update_dirty[`L2_NUM_WAYS-1:0]),
				    .dir_update_dir_core(dir_update_dir_core[`CORE_INDEX_WIDTH-1:0]),
				    .dir_update_directory(dir_update_directory),
				    .dir_update_dir_valid(dir_update_dir_valid),
				    .dir_update_dir_way	(dir_update_dir_way[1:0]),
				    .dir_update_dir_tag	(dir_update_dir_tag[`L1_TAG_WIDTH-1:0]),
				    .dir_update_dir_set	(dir_update_dir_set[`L1_SET_INDEX_WIDTH-1:0]),
				    .dir_hit_l2_way	(dir_hit_l2_way[1:0]));

	l2_cache_dir l2_cache_dir(/*AUTOINST*/
				  // Interfaces
				  .tag_l2req_packet	(tag_l2req_packet),
				  .dir_l2req_packet	(dir_l2req_packet),
				  // Outputs
				  .dir_is_l2_fill	(dir_is_l2_fill),
				  .dir_data_from_memory	(dir_data_from_memory[`CACHE_LINE_BITS-1:0]),
				  .dir_miss_fill_l2_way	(dir_miss_fill_l2_way[1:0]),
				  .dir_hit_l2_way	(dir_hit_l2_way[1:0]),
				  .dir_cache_hit	(dir_cache_hit),
				  .dir_old_l2_tag	(dir_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				  .dir_l1_has_line	(dir_l1_has_line[`NUM_CORES-1:0]),
				  .dir_l1_way		(dir_l1_way[`NUM_CORES*2-1:0]),
				  .dir_l2_dirty		(dir_l2_dirty[`STRANDS_PER_CORE-1:0]),
				  .dir_update_tag_enable(dir_update_tag_enable),
				  .dir_update_tag_valid	(dir_update_tag_valid),
				  .dir_update_tag_tag	(dir_update_tag_tag[`L2_TAG_WIDTH-1:0]),
				  .dir_update_tag_set	(dir_update_tag_set[`L2_SET_INDEX_WIDTH-1:0]),
				  .dir_update_tag_way	(dir_update_tag_way[1:0]),
				  .dir_update_dirty_set	(dir_update_dirty_set[`L2_SET_INDEX_WIDTH-1:0]),
				  .dir_new_dirty	(dir_new_dirty),
				  .dir_update_dirty	(dir_update_dirty[`L2_NUM_WAYS-1:0]),
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
				  .tag_is_restarted_request(tag_is_restarted_request),
				  .tag_data_from_memory	(tag_data_from_memory[`CACHE_LINE_BITS-1:0]),
				  .tag_miss_fill_l2_way	(tag_miss_fill_l2_way[1:0]),
				  .tag_l2_tag		(tag_l2_tag[`L2_TAG_WIDTH*`L2_NUM_WAYS-1:0]),
				  .tag_l2_valid		(tag_l2_valid[`L2_NUM_WAYS-1:0]),
				  .tag_l2_dirty		(tag_l2_dirty[`L2_NUM_WAYS-1:0]),
				  .tag_l1_has_line	(tag_l1_has_line[`NUM_CORES-1:0]),
				  .tag_l1_way		(tag_l1_way[`NUM_CORES*2-1:0]));

	l2_cache_read l2_cache_read(/*AUTOINST*/
				    // Interfaces
				    .dir_l2req_packet	(dir_l2req_packet),
				    .rd_l2req_packet	(rd_l2req_packet),
				    // Outputs
				    .rd_is_l2_fill	(rd_is_l2_fill),
				    .rd_data_from_memory(rd_data_from_memory[`CACHE_LINE_BITS-1:0]),
				    .rd_miss_fill_l2_way(rd_miss_fill_l2_way[1:0]),
				    .rd_hit_l2_way	(rd_hit_l2_way[1:0]),
				    .rd_cache_hit	(rd_cache_hit),
				    .rd_l1_has_line	(rd_l1_has_line[`NUM_CORES-1:0]),
				    .rd_dir_l1_way	(rd_dir_l1_way[`NUM_CORES*2-1:0]),
				    .rd_cache_mem_result(rd_cache_mem_result[`CACHE_LINE_BITS-1:0]),
				    .rd_old_l2_tag	(rd_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				    .rd_line_is_dirty	(rd_line_is_dirty),
				    .rd_store_sync_success(rd_store_sync_success),
				    // Inputs
				    .clk		(clk),
				    .reset		(reset),
				    .dir_is_l2_fill	(dir_is_l2_fill),
				    .dir_data_from_memory(dir_data_from_memory[`CACHE_LINE_BITS-1:0]),
				    .dir_hit_l2_way	(dir_hit_l2_way[1:0]),
				    .dir_cache_hit	(dir_cache_hit),
				    .dir_old_l2_tag	(dir_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				    .dir_l1_has_line	(dir_l1_has_line[`NUM_CORES-1:0]),
				    .dir_l1_way		(dir_l1_way[`NUM_CORES*2-1:0]),
				    .dir_l2_dirty	(dir_l2_dirty[`STRANDS_PER_CORE-1:0]),
				    .dir_miss_fill_l2_way(dir_miss_fill_l2_way[1:0]),
				    .wr_update_enable	(wr_update_enable),
				    .wr_cache_write_index(wr_cache_write_index[`L2_CACHE_ADDR_WIDTH-1:0]),
				    .wr_update_data	(wr_update_data[`CACHE_LINE_BITS-1:0]));

	l2_cache_write l2_cache_write(/*AUTOINST*/
				      // Interfaces
				      .rd_l2req_packet	(rd_l2req_packet),
				      .wr_l2req_packet	(wr_l2req_packet),
				      // Outputs
				      .wr_cache_hit	(wr_cache_hit),
				      .wr_data		(wr_data[`CACHE_LINE_BITS-1:0]),
				      .wr_l1_has_line	(wr_l1_has_line[`NUM_CORES-1:0]),
				      .wr_dir_l1_way	(wr_dir_l1_way[`NUM_CORES*2-1:0]),
				      .wr_is_l2_fill	(wr_is_l2_fill),
				      .wr_update_enable	(wr_update_enable),
				      .wr_cache_write_index(wr_cache_write_index[`L2_CACHE_ADDR_WIDTH-1:0]),
				      .wr_update_data	(wr_update_data[`CACHE_LINE_BITS-1:0]),
				      .wr_store_sync_success(wr_store_sync_success),
				      // Inputs
				      .clk		(clk),
				      .reset		(reset),
				      .rd_is_l2_fill	(rd_is_l2_fill),
				      .rd_data_from_memory(rd_data_from_memory[`CACHE_LINE_BITS-1:0]),
				      .rd_hit_l2_way	(rd_hit_l2_way[1:0]),
				      .rd_cache_hit	(rd_cache_hit),
				      .rd_l1_has_line	(rd_l1_has_line[`NUM_CORES-1:0]),
				      .rd_dir_l1_way	(rd_dir_l1_way[`NUM_CORES*2-1:0]),
				      .rd_cache_mem_result(rd_cache_mem_result[`CACHE_LINE_BITS-1:0]),
				      .rd_miss_fill_l2_way(rd_miss_fill_l2_way[1:0]),
				      .rd_store_sync_success(rd_store_sync_success));

	l2_cache_response l2_cache_response(/*AUTOINST*/
					    // Interfaces
					    .wr_l2req_packet	(wr_l2req_packet),
					    .l2rsp_packet	(l2rsp_packet),
					    // Inputs
					    .clk		(clk),
					    .reset		(reset),
					    .wr_data		(wr_data[`CACHE_LINE_BITS-1:0]),
					    .wr_l1_has_line	(wr_l1_has_line[`NUM_CORES-1:0]),
					    .wr_dir_l1_way	(wr_dir_l1_way[`NUM_CORES*2-1:0]),
					    .wr_cache_hit	(wr_cache_hit),
					    .wr_is_l2_fill	(wr_is_l2_fill),
					    .wr_store_sync_success(wr_store_sync_success));

	l2_cache_bus_interface #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))
		l2_cache_bus_interface(/*AUTOINST*/
				       // Interfaces
				       .rd_l2req_packet	(rd_l2req_packet),
				       .bif_l2req_packet(bif_l2req_packet),
				       // Outputs
				       .bif_input_wait	(bif_input_wait),
				       .bif_duplicate_request(bif_duplicate_request),
				       .bif_load_buffer_vec(bif_load_buffer_vec[`CACHE_LINE_BITS-1:0]),
				       .bif_data_ready	(bif_data_ready),
				       .axi_awaddr	(axi_awaddr[31:0]),
				       .axi_awlen	(axi_awlen[7:0]),
				       .axi_awvalid	(axi_awvalid),
				       .axi_wdata	(axi_wdata[AXI_DATA_WIDTH-1:0]),
				       .axi_wlast	(axi_wlast),
				       .axi_wvalid	(axi_wvalid),
				       .axi_bready	(axi_bready),
				       .axi_araddr	(axi_araddr[31:0]),
				       .axi_arlen	(axi_arlen[7:0]),
				       .axi_arvalid	(axi_arvalid),
				       .axi_rready	(axi_rready),
				       .pc_event_l2_writeback(pc_event_l2_writeback),
				       // Inputs
				       .clk		(clk),
				       .reset		(reset),
				       .rd_is_l2_fill	(rd_is_l2_fill),
				       .rd_cache_hit	(rd_cache_hit),
				       .rd_cache_mem_result(rd_cache_mem_result[`CACHE_LINE_BITS-1:0]),
				       .rd_old_l2_tag	(rd_old_l2_tag[`L2_TAG_WIDTH-1:0]),
				       .rd_line_is_dirty(rd_line_is_dirty),
				       .axi_awready	(axi_awready),
				       .axi_wready	(axi_wready),
				       .axi_bvalid	(axi_bvalid),
				       .axi_arready	(axi_arready),
				       .axi_rvalid	(axi_rvalid),
				       .axi_rdata	(axi_rdata[AXI_DATA_WIDTH-1:0]));
endmodule
