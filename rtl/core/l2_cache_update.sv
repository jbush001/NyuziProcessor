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
// L2 cache pipeline - update stage.
// * Generate signals to update cache data if this is a cache fill or store.
//   This applies the store mask and requested data to the original data.
// * Format a response packet to send back to cores.
//

module l2_cache_update(
	input                                          clk,
	input                                          reset,
                                               
	// From l2_cache_read                          
	input l2req_packet_t                           l2r_request,
	input cache_line_data_t                        l2r_data,
	input                                          l2r_cache_hit,
	input logic[$clog2(`L2_WAYS * `L2_SETS) - 1:0] l2r_hit_cache_idx,
	input                                          l2r_is_l2_fill,
	input cache_line_data_t                        l2r_data_from_memory,
	input                                          l2r_store_sync_success,
	
	// To l2_cache_read
	output logic                                   l2u_write_en,
	output [$clog2(`L2_WAYS * `L2_SETS) - 1:0]     l2u_write_addr,
	output cache_line_data_t                       l2u_write_data,

	// To cores
	output l2rsp_packet_t                          l2_response);

	cache_line_data_t original_data;
	logic update_data;
	l2rsp_packet_type_t response_type;
	
	assign original_data = l2r_is_l2_fill ? l2r_data_from_memory : l2r_data;
	assign update_data = l2r_request.packet_type == L2REQ_STORE
		|| (l2r_request.packet_type == L2REQ_STORE_SYNC && l2r_store_sync_success);
	
	genvar byte_lane;
	generate
		for (byte_lane = 0; byte_lane < `CACHE_LINE_BYTES; byte_lane++)
		begin : lane_mask_gen
			assign l2u_write_data[byte_lane * 8+:8] = (l2r_request.store_mask[byte_lane] && update_data)
				? l2r_request.data[byte_lane * 8+:8]
				: original_data[byte_lane * 8+:8];
		end
	endgenerate
	
	assign l2u_write_en = l2r_request.valid
		&& (l2r_is_l2_fill 
		|| (l2r_cache_hit 
		&& (l2r_request.packet_type == L2REQ_STORE || l2r_request.packet_type == L2REQ_STORE_SYNC)));
	assign l2u_write_addr = l2r_hit_cache_idx;

	// Response packet type
	always_comb
	begin
		case (l2r_request.packet_type)
			L2REQ_LOAD,
			L2REQ_LOAD_SYNC:
				response_type = L2RSP_LOAD_ACK;
				
			L2REQ_STORE,
			L2REQ_STORE_SYNC:
				response_type = L2RSP_STORE_ACK;
				
			L2REQ_FLUSH:
				response_type = L2RSP_FLUSH_ACK;
				
			default:
				response_type = L2RSP_LOAD_ACK;
		endcase
	end

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			l2_response <= 0;
		else
		begin
			if (l2r_request.valid && ((l2r_cache_hit || l2r_is_l2_fill) || l2r_request.packet_type == L2REQ_FLUSH))
			begin
				l2_response.valid <= 1;
				l2_response.status <= l2r_request.packet_type == L2REQ_STORE_SYNC ? l2r_store_sync_success : 1;
				l2_response.core <= l2r_request.core;
				l2_response.id <= l2r_request.id;
				l2_response.packet_type <= response_type;
				l2_response.cache_type <= l2r_request.cache_type;
				l2_response.data <= l2u_write_data;
				l2_response.address <= l2r_request.address;
			end
			else
				l2_response <= 0;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
