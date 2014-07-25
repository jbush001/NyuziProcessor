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

module l2_cache_bus_interface(
	input                                  clk,
	input                                  reset,

	axi_interface                          axi_bus,
	
	// to l2_cache_arb
	output l2req_packet_t                  l2bi_is_l2_fill,
	output logic[`CACHE_LINE_BITS - 1:0]   l2bi_data_from_memory,
	output logic                           l2bi_stall,

	// From l2_cache_read
	input                                  l2r_need_writeback,
	input l2_tag_t                         l2r_replace_tag,
	input [`CACHE_LINE_BITS - 1:0]         l2r_data);


	always_ff @(posedge reset, posedge clk)
	begin
		if (reset)
		begin
			l2bi_is_l2_fill <= 0;
			l2bi_data_from_memory <= 0;
			l2bi_stall <= 0;
		end
		else
		begin
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
