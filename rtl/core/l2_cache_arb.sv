// 
// Copyright 2011-2015 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 


`include "defines.sv"

//
// l2 request arbiter stage.  Selects between different core L2 requests and a restarted
// request.  l2_ready depends combinationally on the valid signals in the 
// request packets, so valid bits must not be dependent on l2_ready to avoid a loop.
//

module l2_cache_arb(
	input                                 clk,
	input                                 reset,

	// From cores
	input l2req_packet_t                  l2i_request[`NUM_CORES],
	output logic                          l2_ready[`NUM_CORES],

	// To l2_cache_tag
	output l2req_packet_t                 l2a_request,
	output cache_line_data_t              l2a_data_from_memory,
	output logic                          l2a_is_l2_fill,
	
	// From bus interface
	input                                 l2bi_ready,
	input l2req_packet_t                  l2bi_request,
	input cache_line_data_t               l2bi_data_from_memory,
	input                                 l2bi_stall,
	input                                 l2bi_collided_miss);

	logic[`NUM_CORES - 1:0] arb_request;
	core_id_t grant_idx;
	logic[`NUM_CORES - 1:0] grant_oh;
	logic can_accept_request;
	
	assign can_accept_request = !l2bi_ready && !l2bi_stall;

	genvar request_idx;
	generate
		for (request_idx = 0; request_idx < `NUM_CORES; request_idx++)
		begin : handshake_gen
			assign arb_request[request_idx] = l2i_request[request_idx].valid;
			assign l2_ready[request_idx] = grant_oh[request_idx] && can_accept_request;
		end
	endgenerate

	generate
		if (`NUM_CORES > 1)
		begin
			arbiter #(.NUM_ENTRIES(`NUM_CORES)) arbiter_request(
				.request(arb_request),
				.update_lru(can_accept_request),
				.grant_oh(grant_oh),
				.*);

			oh_to_idx #(.NUM_SIGNALS(`NUM_CORES)) oh_to_idx_grant(
				.one_hot(grant_oh),
				.index(grant_idx));
		end
		else
		begin
			assign grant_idx = 0;
			assign grant_oh = arb_request[0];
		end
	endgenerate

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			l2a_request <= 0;
			l2a_is_l2_fill <= 0;
			l2a_data_from_memory <= 0;
		end
		else
		begin
			if (l2bi_ready)
			begin
				// Restarted request from external bus interface

				// These messages types should not cause a cache miss, and thus should 
				// not be restarted
				assert(l2bi_request.packet_type != L2REQ_IINVALIDATE);
				assert(l2bi_request.packet_type != L2REQ_DINVALIDATE);
				assert(l2bi_request.packet_type != L2REQ_FLUSH);
					
				l2a_request <= l2bi_request;
				l2a_is_l2_fill <= !l2bi_collided_miss;
				l2a_data_from_memory <= l2bi_data_from_memory;
			end
			else if (|grant_oh && can_accept_request)
			begin
				// New request from a core
				l2a_request <= l2i_request[grant_idx];
				l2a_is_l2_fill <= 0;
			end
			else
			begin
				l2a_request.valid <= 0;
				l2a_is_l2_fill <= 0;
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
