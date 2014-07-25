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
	input l2req_packet_t              l2r_request,
	input[`CACHE_LINE_BITS - 1:0]     l2w_data,

	// To cores
	output l2rsp_packet_t             l2_response);

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			l2_response <= 0;
		end
		else
		begin

		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
