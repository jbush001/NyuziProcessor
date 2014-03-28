// 
// Copyright 2011-2012 Jeff Bush
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
