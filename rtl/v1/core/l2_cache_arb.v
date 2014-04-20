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
// L2 cache pipeline arbitration stage
// Determines whether a request from a core or a restarted request from
// the system memory interface queue should be pushed down the pipeline.
// The latter always has priority.
//

module l2_cache_arb(
	input                                   clk,
	input                                   reset,
	output                                  l2req_ready,
	input l2req_packet_t                    l2req_packet,
	input l2req_packet_t                    bif_l2req_packet,
	output l2req_packet_t                   arb_l2req_packet,
	input                                   bif_input_wait,
	input [`CACHE_LINE_BITS - 1:0]          bif_load_buffer_vec,
	input                                   bif_data_ready,
	input                                   bif_duplicate_request,
	output logic                            arb_is_l2_fill,
	output logic[`CACHE_LINE_BITS - 1:0]    arb_data_from_memory);

	assign l2req_ready = !bif_data_ready && !bif_input_wait;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			arb_l2req_packet <= 0;
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			arb_data_from_memory <= {(1+(`CACHE_LINE_BITS-1)){1'b0}};
			arb_is_l2_fill <= 1'h0;
			// End of automatics
		end
		else if (bif_data_ready)	
		begin
			// Restarted request
			arb_l2req_packet <= bif_l2req_packet;
			arb_is_l2_fill <= !bif_duplicate_request;
			arb_data_from_memory <= bif_load_buffer_vec;
		end
		else if (!bif_input_wait)	// Don't accept requests if SMI queue is full
		begin
			arb_l2req_packet <= l2req_packet;
			arb_is_l2_fill <= 0;
			arb_data_from_memory <= 0;
		end
		else
		begin
			arb_is_l2_fill <= 0;
			arb_l2req_packet <= 0;	// XXX could simply clear valid, but this simplifies debugging.
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
