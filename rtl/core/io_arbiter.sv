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
// Accepts IO requests from cores, asserts signals on external IO bus,
// sends responses back to cores.
//

module io_arbiter(
	input                     clk,
	input                     reset,
	input ioreq_packet_t      io_request[`NUM_CORES],
	output logic              ia_ready[`NUM_CORES],
	output iorsp_packet_t     ia_response,

	// Non-cacheable memory signals
	output logic              io_write_en,
	output logic              io_read_en,
	output scalar_t           io_address,
	output scalar_t           io_write_data,
	input scalar_t            io_read_data);

	logic[`NUM_CORES - 1:0] arb_request;
	core_id_t grant_idx;
	logic[`NUM_CORES - 1:0] grant_oh;
	logic request_sent;
	core_id_t request_core;
	thread_idx_t request_thread_idx;
	
	genvar request_idx;
	generate
		for (request_idx = 0; request_idx < `NUM_CORES; request_idx++)
		begin : handshake_gen
			assign arb_request[request_idx] = io_request[request_idx].valid;
			assign ia_ready[request_idx] = grant_oh[request_idx];
		end
	endgenerate

	generate
		if (`NUM_CORES > 1)
		begin
			arbiter #(.NUM_ENTRIES(`NUM_CORES)) arbiter_request(
				.request(arb_request),
				.update_lru(1'b1),
				.grant_oh(grant_oh),
				.*);

			oh_to_idx #(.NUM_SIGNALS(`NUM_CORES)) oh_to_idx_grant(
				.one_hot(grant_oh),
				.index(grant_idx));
		end
		else
		begin
			assign grant_oh[0] = arb_request[0];
			assign grant_idx = 0;
		end
	endgenerate

	assign io_write_en = |grant_oh && io_request[grant_idx].is_store;
	assign io_read_en = |grant_oh && !io_request[grant_idx].is_store;
	assign io_write_data = io_request[grant_idx].value;
	assign io_address = io_request[grant_idx].address;
		
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			request_sent <= 0;
			ia_response <= 0;
		end
		else
		begin
			if (|grant_oh)
			begin
				// Send a new request
				request_sent <= 1;
				request_core <= grant_idx;
				request_thread_idx <= io_request[grant_idx].thread_idx;
			end
			else
				request_sent <= 0;
			
			if (request_sent)
			begin
				// Next cycle after request, record response
				ia_response.valid <= 1;
				ia_response.core <= request_core;
				ia_response.thread_idx <= request_thread_idx;
				ia_response.read_value <= io_read_data;
			end
			else
				ia_response.valid <= 0;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


