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

//
// Arbitrates for the L2 request interface (l2req) between store buffer, L1 instruction 
// cache, and L1 data cache and muxes control signals.  
//

module l2req_arbiter_mux(
	input				clk,
	input				reset_n,
	output 				l2req_valid,
	input				l2req_ready,
	output [1:0]		l2req_strand,
	output [1:0]		l2req_unit,
	output [2:0]		l2req_op,
	output [1:0]		l2req_way,
	output [25:0]		l2req_address,
	output [511:0]		l2req_data,
	output [63:0]		l2req_mask,
	input				icache_l2req_valid,
	output				icache_l2req_ready,
	input [1:0]			icache_l2req_strand,
	input [1:0]			icache_l2req_unit,
	input [2:0]			icache_l2req_op,
	input [1:0]			icache_l2req_way,
	input [25:0]		icache_l2req_address,
	input [511:0]		icache_l2req_data,
	input [63:0]		icache_l2req_mask,
	input 				dcache_l2req_valid,
	output				dcache_l2req_ready,
	input [1:0]			dcache_l2req_strand,
	input [1:0]			dcache_l2req_unit,
	input [2:0]			dcache_l2req_op,
	input [1:0]			dcache_l2req_way,
	input [25:0]		dcache_l2req_address,
	input [511:0]		dcache_l2req_data,
	input [63:0]		dcache_l2req_mask,
	input 				stbuf_l2req_valid,
	output				stbuf_l2req_ready,
	input [1:0]			stbuf_l2req_strand,
	input [1:0]			stbuf_l2req_unit,
	input [2:0]			stbuf_l2req_op,
	input [1:0]			stbuf_l2req_way,
	input [25:0]		stbuf_l2req_address,
	input [511:0]		stbuf_l2req_data,
	input [63:0]		stbuf_l2req_mask);

	wire icache_grant;
	wire dcache_grant;
	wire stbuf_grant;
	wire[1:0] selected_unit;
	
	localparam L2REQ_SIZE = 611;

	// Latched requests
	reg[L2REQ_SIZE - 1:0] icache_request_l;
	reg icache_request_pending;
	reg[L2REQ_SIZE - 1:0] dcache_request_l;
	reg dcache_request_pending;
	reg[L2REQ_SIZE - 1:0] stbuf_request_l;
	reg stbuf_request_pending;

	// Note that, if we are issuing a request from a unit, we can
	// latch a new one in the same cycle.
	assign icache_l2req_ready = !icache_request_pending || (icache_grant && l2req_ready);
	assign dcache_l2req_ready = !dcache_request_pending || (dcache_grant && l2req_ready);
	assign stbuf_l2req_ready = !stbuf_request_pending || (stbuf_grant && l2req_ready);

	always @(posedge clk, negedge reset_n)
	begin
		if (!reset_n)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dcache_request_l <= {L2REQ_SIZE{1'b0}};
			dcache_request_pending <= 1'h0;
			icache_request_l <= {L2REQ_SIZE{1'b0}};
			icache_request_pending <= 1'h0;
			stbuf_request_l <= {L2REQ_SIZE{1'b0}};
			stbuf_request_pending <= 1'h0;
			// End of automatics
		end
		else
		begin
			if (icache_l2req_valid && icache_l2req_ready)
			begin
				icache_request_pending <= #1 1;
				icache_request_l <= #1 {
					icache_l2req_strand,
					icache_l2req_unit,
					icache_l2req_op,
					icache_l2req_way,
					icache_l2req_address,
					icache_l2req_data,
					icache_l2req_mask
				};
			end
			else if (icache_grant && l2req_ready)
				icache_request_pending <= #1 0;
	
			if (dcache_l2req_valid && dcache_l2req_ready)
			begin
				dcache_request_pending <= #1 1;
				dcache_request_l <= #1 {
					dcache_l2req_strand,
					dcache_l2req_unit,
					dcache_l2req_op,
					dcache_l2req_way,
					dcache_l2req_address,
					dcache_l2req_data,
					dcache_l2req_mask
				};
			end
			else if (dcache_grant && l2req_ready)
				dcache_request_pending <= #1 0;
	
			if (stbuf_l2req_valid && stbuf_l2req_ready)
			begin
				stbuf_request_pending <= #1 1;
				stbuf_request_l <= #1 {
					stbuf_l2req_strand,
					stbuf_l2req_unit,
					stbuf_l2req_op,
					stbuf_l2req_way,
					stbuf_l2req_address,
					stbuf_l2req_data,
					stbuf_l2req_mask
				};
			end
			else if (stbuf_grant && l2req_ready)
				stbuf_request_pending <= #1 0;
		end
	end

	arbiter #(3) arbiter(
		.request({ icache_request_pending, dcache_request_pending, stbuf_request_pending }),
		.update_lru(l2req_ready),
		.grant_oh({ icache_grant, dcache_grant, stbuf_grant }),
		/*AUTOINST*/
			     // Inputs
			     .clk		(clk),
			     .reset_n		(reset_n)); 
	assign selected_unit = { stbuf_grant, dcache_grant };	// Convert one hot to index

	reg[L2REQ_SIZE - 1:0] reqout;
	always @*
	begin
		case (selected_unit)
			2'd0: reqout = icache_request_l;
			2'd1: reqout = dcache_request_l;
			2'd2: reqout = stbuf_request_l;
			default: reqout = icache_request_l;	// XXX Don't care
		endcase
	end

	assign { l2req_strand, l2req_unit, l2req_op, l2req_way, l2req_address,
			l2req_data, l2req_mask } = reqout;
	
	assign l2req_valid = icache_request_pending || dcache_request_pending
		|| stbuf_request_pending;
endmodule
