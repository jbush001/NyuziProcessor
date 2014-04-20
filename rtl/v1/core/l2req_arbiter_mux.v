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
// Arbitrates for the L2 request interface (l2req) between store buffer, L1 instruction 
// cache, and L1 data cache and muxes control signals.  
//

module l2req_arbiter_mux(
	input                                clk,
	input                                reset,
	input                                l2req_ready,
	output l2req_packet_t                l2req_packet,
	input l2req_packet_t                 icache_l2req_packet,
	output                               icache_l2req_ready,
	input l2req_packet_t                 dcache_l2req_packet,
	output                               dcache_l2req_ready,
	input l2req_packet_t                 stbuf_l2req_packet,
	output                               stbuf_l2req_ready);

	logic icache_grant;
	logic dcache_grant;
	logic stbuf_grant;
	logic[1:0] selected_unit;
	
	// Latched requests
	l2req_packet_t icache_request_l;
	logic icache_request_pending;
	l2req_packet_t dcache_request_l;
	logic dcache_request_pending;
	l2req_packet_t stbuf_request_l;
	logic stbuf_request_pending;

	// Note that, if we are issuing a request from a unit, we can
	// latch a new one in the same cycle.
	assign icache_l2req_ready = !icache_request_pending || (icache_grant && l2req_ready);
	assign dcache_l2req_ready = !dcache_request_pending || (dcache_grant && l2req_ready);
	assign stbuf_l2req_ready = !stbuf_request_pending || (stbuf_grant && l2req_ready);

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dcache_request_l <= 1'h0;
			dcache_request_pending <= 1'h0;
			icache_request_l <= 1'h0;
			icache_request_pending <= 1'h0;
			stbuf_request_l <= 1'h0;
			stbuf_request_pending <= 1'h0;
			// End of automatics
		end
		else
		begin
			if (icache_l2req_packet.valid && icache_l2req_ready)
			begin
				icache_request_pending <= 1;
				icache_request_l <= icache_l2req_packet;
			end
			else if (icache_grant && l2req_ready)
				icache_request_pending <= 0;
	
			if (dcache_l2req_packet.valid && dcache_l2req_ready)
			begin
				dcache_request_pending <= 1;
				dcache_request_l <= dcache_l2req_packet;
			end
			else if (dcache_grant && l2req_ready)
				dcache_request_pending <= 0;
	
			if (stbuf_l2req_packet.valid && stbuf_l2req_ready)
			begin
				stbuf_request_pending <= 1;
				stbuf_request_l <= stbuf_l2req_packet;
			end
			else if (stbuf_grant && l2req_ready)
				stbuf_request_pending <= 0;
		end
	end

	arbiter #(.NUM_ENTRIES(3)) arbiter(
		.request({ icache_request_pending, dcache_request_pending, stbuf_request_pending }),
		.update_lru(l2req_ready),
		.grant_oh({ icache_grant, dcache_grant, stbuf_grant }),
		.*);

	assign selected_unit = { stbuf_grant, dcache_grant };	// Convert one hot to index

	always_comb
	begin
		if (icache_grant || dcache_grant || stbuf_grant)
		begin
			unique case (selected_unit)
				2'd0: l2req_packet = icache_request_l;
				2'd1: l2req_packet = dcache_request_l;
				2'd2: l2req_packet = stbuf_request_l;
				default: l2req_packet = 0;	// XXX Don't care
			endcase
		end
		else
			l2req_packet = 0;
	end
	
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

