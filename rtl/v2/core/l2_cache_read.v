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

`include "defines.v"

//
// Check for cache hit and read cache data memory
//

module l2_cache_read(
	input                                     clk,
	input                                     reset,

	// From l2_cache_tag                     
	input l2req_packet_t                      l2t_request,
	input                                     l2t_valid[`L2_WAYS],
	input l2_tag_t                            l2t_tag[`L2_WAYS],
	input                                     l2t_dirty[`L2_WAYS],
	input                                     l2t_is_l2_fill,
	input l2_way_idx_t                        l2t_fill_way,
	input [`CACHE_LINE_BITS - 1:0]            l2t_data_from_memory,
                                             
	// from l2_cache_write                   
	input                                     l2w_write_en,
	input [$clog2(`L2_WAYS * `L2_SETS) - 1:0] l2w_write_addr,
	input [`CACHE_LINE_BITS - 1:0]            l2w_write_data,
                                              
	// To l2_cache_write                   
	output l2req_packet_t                     l2r_request,
	output logic[`CACHE_LINE_BITS - 1:0]      l2r_data,	// Also to bus interface unit
	output logic                              l2r_cache_hit,
	output logic                              l2r_is_l2_fill,
	output [`CACHE_LINE_BITS - 1:0]           l2r_data_from_memory,
	
	// To bus interface unit
	output l2_tag_t                           l2r_replace_tag,
	output logic                              l2r_need_writeback);

	logic[`L2_WAYS - 1:0] way_hit_oh;
	l2_addr_t l2_addr;
	logic cache_hit;
	l1i_way_idx_t way_hit_idx;
	logic[$clog2(`L2_WAYS * `L2_SETS) - 1:0] read_address;
	
	assign l2_addr = l2a_request.address;

	// 
	// Check for cache hit
	//
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L2_WAYS; way_idx++)
		begin : hit_check_logic
			assign way_hit_oh[way_idx] = l2_addr.tag == l2t_tag[way_idx] && l2t_valid[way_idx]; 
		end
	endgenerate

	assign cache_hit = |way_hit_oh;

	one_hot_to_index #(.NUM_SIGNALS(`L1D_WAYS)) encode_hit_way(
		.one_hot(way_hit_oh),
		.index(way_hit_idx));

	assign read_address = { (l2t_is_l2_fill ? way_hit_idx : l2t_fill_way), l2_addr.set_idx};

	// Cache memory
	sram_1r1w #(
		.DATA_WIDTH(`CACHE_LINE_BITS), 
		.SIZE(`L2_WAYS * `L2_SETS)
	) l2_data(
		// Instruction pipeline access.  Note that there is only one store port that is shared by the
		// interconnect.  If both attempt access in the same cycle, the interconnect will win and 
		// the thread will be rolled back.
		.read_en(l2t_request.valid && (cache_hit || l2t_is_l2_fill)),
		.read_addr(read_address),
		.read_data(l2r_data),
		.write_en(l2w_write_en),	
		.write_addr(l2w_write_addr),
		.write_data(l2w_write_data),
		.*);

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			l2r_request <= 0;
			l2r_cache_hit <= 0;
			l2r_is_l2_fill <= 0;
		end
		else
		begin
			l2r_request <= l2t_request;
			l2r_cache_hit <= cache_hit;
			l2r_is_l2_fill <= l2t_is_l2_fill;
			l2r_replace_tag <= l2t_tag[l2t_fill_way];
			l2r_need_writeback <= l2t_valid[l2t_fill_way] && l2t_dirty[l2t_fill_way];
			l2r_data_from_memory <= l2t_data_from_memory;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
