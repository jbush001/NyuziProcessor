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
// Format response packet
//

module l2_cache_response(
	input                             clk,
	input                             reset,
                                      
	// From l2_write stage            
	input l2req_packet_t              l2w_request,
	input[`CACHE_LINE_BITS - 1:0]     l2w_data,
	input                             l2w_cache_hit,
	input                             l2w_is_l2_fill,
	input                             l2w_store_sync_success,

	// To cores
	output l2rsp_packet_t             l2_response);

	l2rsp_packet_type_t packet_type;
	
	always_comb
	begin
		case (l2w_request.packet_type)
			L2REQ_LOAD,
			L2REQ_LOAD_SYNC:
				packet_type = L2RSP_LOAD_ACK;
				
			L2REQ_STORE,
			L2REQ_STORE_SYNC:
				packet_type = L2RSP_STORE_ACK;
		endcase
	end

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			l2_response <= 0;
		end
		else
		begin
			if (l2w_request.valid && (l2w_cache_hit || l2w_is_l2_fill))
			begin
				l2_response.valid <= 1;
				l2_response.status <= l2w_request.packet_type == L2REQ_STORE_SYNC ? l2w_store_sync_success : 1;
				l2_response.core <= l2w_request.core;
				l2_response.id <= l2w_request.id;
				l2_response.packet_type <= packet_type;
				l2_response.cache_type <= l2w_request.cache_type;
				l2_response.data <= l2w_data;
				l2_response.address <= l2w_request.address;
			end
			else
				l2_response <= 0;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
