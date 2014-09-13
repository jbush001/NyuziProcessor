//
// Copyright (C) 2014 Jeff Bush
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

`include "defines.sv"

//
// L2 cache. If there is a cache miss, it is put into a queue to be filled. When 
// it has been satisified, the original packet is fed back into the L2 cache
// pipeline.
// The L2 cache is pipelined and has 4 stages:
//  - Arbitrate: chooses between requests from cores, or a restarted request
//    that has been filled from system memory.  Restarted requests always
//    take precedence to avoid deadlock.
//  - Tag: issues address to tag ram ways, checks LRU.
//  - Read: checks for cache hit, reads cache memory
//  - Update: generates signals to update cache memory and sends response packet
//

module l2_cache(
	input                        clk,
	input                        reset,
	input l2req_packet_t         l2i_request[`NUM_CORES],
	output                       l2_ready[`NUM_CORES],
	output l2rsp_packet_t        l2_response,
	axi_interface.master         axi_bus,
	output logic                 perf_l2_miss,
	output logic                 perf_l2_hit,
	output logic                 perf_l2_writeback);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	cache_line_data_t l2a_data_from_memory;	// From l2_cache_arb of l2_cache_arb.v
	logic		l2a_is_l2_fill;		// From l2_cache_arb of l2_cache_arb.v
	l2req_packet_t	l2a_request;		// From l2_cache_arb of l2_cache_arb.v
	wire		l2bi_collided_miss;	// From l2_axi_bus_interface of l2_axi_bus_interface.v
	logic		l2bi_ready;		// From l2_axi_bus_interface of l2_axi_bus_interface.v
	logic		l2bi_stall;		// From l2_axi_bus_interface of l2_axi_bus_interface.v
	logic		l2r_cache_hit;		// From l2_cache_read of l2_cache_read.v
	cache_line_data_t l2r_data;		// From l2_cache_read of l2_cache_read.v
	cache_line_data_t l2r_data_from_memory;	// From l2_cache_read of l2_cache_read.v
	logic [$clog2(`L2_WAYS*`L2_SETS)-1:0] l2r_hit_cache_idx;// From l2_cache_read of l2_cache_read.v
	logic		l2r_is_l2_fill;		// From l2_cache_read of l2_cache_read.v
	logic		l2r_needs_writeback;	// From l2_cache_read of l2_cache_read.v
	l2req_packet_t	l2r_request;		// From l2_cache_read of l2_cache_read.v
	logic		l2r_store_sync_success;	// From l2_cache_read of l2_cache_read.v
	logic [`L2_WAYS-1:0] l2r_update_dirty_en;// From l2_cache_read of l2_cache_read.v
	l2_set_idx_t	l2r_update_dirty_set;	// From l2_cache_read of l2_cache_read.v
	logic		l2r_update_dirty_value;	// From l2_cache_read of l2_cache_read.v
	logic		l2r_update_lru_en;	// From l2_cache_read of l2_cache_read.v
	l2_way_idx_t	l2r_update_lru_hit_way;	// From l2_cache_read of l2_cache_read.v
	logic [`L2_WAYS-1:0] l2r_update_tag_en;	// From l2_cache_read of l2_cache_read.v
	l2_set_idx_t	l2r_update_tag_set;	// From l2_cache_read of l2_cache_read.v
	logic		l2r_update_tag_valid;	// From l2_cache_read of l2_cache_read.v
	l2_tag_t	l2r_update_tag_value;	// From l2_cache_read of l2_cache_read.v
	l2_tag_t	l2r_writeback_tag;	// From l2_cache_read of l2_cache_read.v
	cache_line_data_t l2t_data_from_memory;	// From l2_cache_tag of l2_cache_tag.v
	logic		l2t_dirty [`L2_WAYS];	// From l2_cache_tag of l2_cache_tag.v
	l2_way_idx_t	l2t_fill_way;		// From l2_cache_tag of l2_cache_tag.v
	logic		l2t_is_l2_fill;		// From l2_cache_tag of l2_cache_tag.v
	l2req_packet_t	l2t_request;		// From l2_cache_tag of l2_cache_tag.v
	l2_tag_t	l2t_tag [`L2_WAYS];	// From l2_cache_tag of l2_cache_tag.v
	logic		l2t_valid [`L2_WAYS];	// From l2_cache_tag of l2_cache_tag.v
	wire [$clog2(`L2_WAYS*`L2_SETS)-1:0] l2u_write_addr;// From l2_cache_update of l2_cache_update.v
	cache_line_data_t l2u_write_data;	// From l2_cache_update of l2_cache_update.v
	logic		l2u_write_en;		// From l2_cache_update of l2_cache_update.v
	// End of automatics
	l2req_packet_t l2bi_request;
	cache_line_data_t l2bi_data_from_memory;

	l2_cache_arb l2_cache_arb(.*);
	l2_cache_tag l2_cache_tag(.*);
	l2_cache_read l2_cache_read(.*);
	l2_cache_update l2_cache_update(.*);

	l2_axi_bus_interface l2_axi_bus_interface(.*);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
