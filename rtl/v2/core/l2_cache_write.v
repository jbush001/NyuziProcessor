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
// Generate signals to update cache data
//

module l2_cache_write(
	input                                      clk,
	input                                      reset,
                                               
	// From l2_cache_read                      
	input l2req_packet_t                       l2r_request,
	input [`CACHE_LINE_BITS - 1:0]             l2r_data,
	input                                      l2r_cache_hit,
	input logic[$clog2(`L2_WAYS * `L2_SETS) - 1:0] l2r_hit_cache_idx,
	input                                      l2r_is_l2_fill,
	input [`CACHE_LINE_BITS - 1:0]             l2r_data_from_memory,
	input                                      l2r_store_sync_success,

	// to l2_cache_response
	output logic                               l2w_write_en,
	output [$clog2(`L2_WAYS * `L2_SETS) - 1:0] l2w_write_addr,
	output [`CACHE_LINE_BITS - 1:0]            l2w_write_data,
	output logic                               l2w_cache_hit,
	output logic                               l2w_is_l2_fill,
	output logic                               l2w_store_sync_success,
	
	// to l2_cache_response
	output l2req_packet_t                      l2w_request,
	output [`CACHE_LINE_BITS - 1:0]            l2w_data);

	logic[`CACHE_LINE_BITS - 1:0] original_data;
	logic update_data;
	
	assign original_data = l2r_is_l2_fill ? l2r_data_from_memory : l2r_data;
	assign update_data = l2r_request.packet_type == L2REQ_STORE
		|| (l2r_request.packet_type == L2REQ_STORE_SYNC && l2r_store_sync_success);
	
	genvar byte_lane;
	generate
		for (byte_lane = 0; byte_lane < `CACHE_LINE_BYTES; byte_lane++)
		begin
			assign l2w_write_data[byte_lane * 8+:8] = (l2r_request.store_mask[byte_lane] && update_data)
				? l2r_request.data[byte_lane * 8+:8]
				: original_data[byte_lane * 8+:8];
		end
	endgenerate
	
	assign l2w_write_en = l2r_request.valid
		&& (l2r_is_l2_fill 
		|| (l2r_cache_hit 
		&& (l2r_request.packet_type == L2REQ_STORE || l2r_request.packet_type == L2REQ_STORE_SYNC)));
	assign l2w_write_addr = l2r_hit_cache_idx;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			l2w_request <= 0;
			l2w_data <= 0;
			l2w_cache_hit <= 0;
			l2w_is_l2_fill <= 0;
			l2w_store_sync_success <= 0;
		end
		else
		begin
			l2w_request <= l2r_request;
			l2w_data <= l2w_write_data;
			l2w_cache_hit <= l2r_cache_hit;
			l2w_is_l2_fill <= l2r_is_l2_fill;
			l2w_store_sync_success <= l2r_store_sync_success;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
