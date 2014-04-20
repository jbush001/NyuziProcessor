// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
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
	(input                               clk,
	input                                reset,

	// L2 Request interface
	input l2req_packet_t                 l2req_packet,
	output                               l2req_ready,
	
	// L2 Response Interface
	output l2rsp_packet_t                l2rsp_packet,
	
	// AXI external memory interface
	axi_interface                        axi_bus,
	
	// To performance counters
	output                               pc_event_l2_hit,
	output                               pc_event_l2_miss,
	output                               pc_event_store,
	output                               pc_event_l2_wait,
	output                               pc_event_l2_writeback);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic [`CACHE_LINE_BITS-1:0] arb_data_from_memory;// From l2_cache_arb of l2_cache_arb.v
	logic		arb_is_l2_fill;		// From l2_cache_arb of l2_cache_arb.v
	l2req_packet_t	arb_l2req_packet;	// From l2_cache_arb of l2_cache_arb.v
	logic		bif_data_ready;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire		bif_duplicate_request;	// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire		bif_input_wait;		// From l2_cache_bus_interface of l2_cache_bus_interface.v
	l2req_packet_t	bif_l2req_packet;	// From l2_cache_bus_interface of l2_cache_bus_interface.v
	wire [`CACHE_LINE_BITS-1:0] bif_load_buffer_vec;// From l2_cache_bus_interface of l2_cache_bus_interface.v
	logic		dir_cache_hit;		// From l2_cache_dir of l2_cache_dir.v
	logic [`CACHE_LINE_BITS-1:0] dir_data_from_memory;// From l2_cache_dir of l2_cache_dir.v
	logic [1:0]	dir_hit_l2_way;		// From l2_cache_dir of l2_cache_dir.v
	logic		dir_is_l2_fill;		// From l2_cache_dir of l2_cache_dir.v
	logic [`NUM_CORES-1:0] dir_l1_has_line;	// From l2_cache_dir of l2_cache_dir.v
	logic [`NUM_CORES*2-1:0] dir_l1_way;	// From l2_cache_dir of l2_cache_dir.v
	logic [`STRANDS_PER_CORE-1:0] dir_l2_dirty;// From l2_cache_dir of l2_cache_dir.v
	l2req_packet_t	dir_l2req_packet;	// From l2_cache_dir of l2_cache_dir.v
	logic [1:0]	dir_miss_fill_l2_way;	// From l2_cache_dir of l2_cache_dir.v
	logic		dir_new_dirty;		// From l2_cache_dir of l2_cache_dir.v
	logic [`L2_TAG_WIDTH-1:0] dir_old_l2_tag;// From l2_cache_dir of l2_cache_dir.v
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
	logic		rd_cache_hit;		// From l2_cache_read of l2_cache_read.v
	logic [`L2_CACHE_ADDR_WIDTH-1:0] rd_cache_index;// From l2_cache_read of l2_cache_read.v
	wire [`CACHE_LINE_BITS-1:0] rd_cache_mem_result;// From l2_cache_read of l2_cache_read.v
	logic [`CACHE_LINE_BITS-1:0] rd_data_from_memory;// From l2_cache_read of l2_cache_read.v
	logic [`NUM_CORES*2-1:0] rd_dir_l1_way;	// From l2_cache_read of l2_cache_read.v
	logic [1:0]	rd_hit_l2_way;		// From l2_cache_read of l2_cache_read.v
	logic		rd_is_l2_fill;		// From l2_cache_read of l2_cache_read.v
	logic [`NUM_CORES-1:0] rd_l1_has_line;	// From l2_cache_read of l2_cache_read.v
	l2req_packet_t	rd_l2req_packet;	// From l2_cache_read of l2_cache_read.v
	logic		rd_line_is_dirty;	// From l2_cache_read of l2_cache_read.v
	logic [1:0]	rd_miss_fill_l2_way;	// From l2_cache_read of l2_cache_read.v
	logic [`L2_TAG_WIDTH-1:0] rd_old_l2_tag;// From l2_cache_read of l2_cache_read.v
	logic		rd_store_sync_success;	// From l2_cache_read of l2_cache_read.v
	logic [`CACHE_LINE_BITS-1:0] tag_data_from_memory;// From l2_cache_tag of l2_cache_tag.v
	logic		tag_is_l2_fill;		// From l2_cache_tag of l2_cache_tag.v
	wire [`NUM_CORES-1:0] tag_l1_has_line;	// From l2_cache_tag of l2_cache_tag.v
	wire [`NUM_CORES*2-1:0] tag_l1_way;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_NUM_WAYS-1:0] tag_l2_dirty;	// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_TAG_WIDTH*`L2_NUM_WAYS-1:0] tag_l2_tag;// From l2_cache_tag of l2_cache_tag.v
	wire [`L2_NUM_WAYS-1:0] tag_l2_valid;	// From l2_cache_tag of l2_cache_tag.v
	l2req_packet_t	tag_l2req_packet;	// From l2_cache_tag of l2_cache_tag.v
	logic [1:0]	tag_miss_fill_l2_way;	// From l2_cache_tag of l2_cache_tag.v
	logic		wr_cache_hit;		// From l2_cache_write of l2_cache_write.v
	logic [`L2_CACHE_ADDR_WIDTH-1:0] wr_cache_write_index;// From l2_cache_write of l2_cache_write.v
	logic [`CACHE_LINE_BITS-1:0] wr_data;	// From l2_cache_write of l2_cache_write.v
	logic [`NUM_CORES*2-1:0] wr_dir_l1_way;	// From l2_cache_write of l2_cache_write.v
	logic		wr_is_l2_fill;		// From l2_cache_write of l2_cache_write.v
	logic [`NUM_CORES-1:0] wr_l1_has_line;	// From l2_cache_write of l2_cache_write.v
	l2req_packet_t	wr_l2req_packet;	// From l2_cache_write of l2_cache_write.v
	logic		wr_store_sync_success;	// From l2_cache_write of l2_cache_write.v
	wire [`CACHE_LINE_BITS-1:0] wr_update_data;// From l2_cache_write of l2_cache_write.v
	wire		wr_update_enable;	// From l2_cache_write of l2_cache_write.v
	// End of automatics
	
	assign pc_event_l2_wait = l2req_packet.valid && !l2req_ready;
	
	l2_cache_arb l2_cache_arb(.*);
	l2_cache_tag l2_cache_tag  (.*);
	l2_cache_dir l2_cache_dir(.*);
	l2_cache_read l2_cache_read(.*);
	l2_cache_write l2_cache_write(.*);
	l2_cache_response l2_cache_response(.*);
	l2_cache_bus_interface l2_cache_bus_interface(.*);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
