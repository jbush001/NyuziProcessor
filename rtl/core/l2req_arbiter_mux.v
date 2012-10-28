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
// cache, and L1 data cache and muxes control signals.  This currently uses a very simple 
// fixed priority arbiter.
//

module l2req_arbiter_mux(
	input				clk,
	output 				l2req_valid,
	input				l2req_ack,
	output reg[1:0]		l2req_strand = 0,
	output reg[1:0]		l2req_unit = 0,
	output reg[2:0]		l2req_op = 0,
	output reg[1:0]		l2req_way = 0,
	output reg[25:0]	l2req_address = 0,
	output reg[511:0]	l2req_data = 0,
	output reg[63:0]	l2req_mask = 0,
	output				icache_l2req_selected,
	output				dcache_l2req_selected,
	output				stbuf_l2req_selected,
	input				icache_l2req_valid,
	input [1:0]			icache_l2req_strand,
	input [1:0]			icache_l2req_unit,
	input [2:0]			icache_l2req_op,
	input [1:0]			icache_l2req_way,
	input [25:0]		icache_l2req_address,
	input [511:0]		icache_l2req_data,
	input [63:0]		icache_l2req_mask,
	input 				dcache_l2req_valid,
	input [1:0]			dcache_l2req_strand,
	input [1:0]			dcache_l2req_unit,
	input [2:0]			dcache_l2req_op,
	input [1:0]			dcache_l2req_way,
	input [25:0]		dcache_l2req_address,
	input [511:0]		dcache_l2req_data,
	input [63:0]		dcache_l2req_mask,
	input 				stbuf_l2req_valid,
	input [1:0]			stbuf_l2req_strand,
	input [1:0]			stbuf_l2req_unit,
	input [2:0]			stbuf_l2req_op,
	input [1:0]			stbuf_l2req_way,
	input [25:0]		stbuf_l2req_address,
	input [511:0]		stbuf_l2req_data,
	input [63:0]		stbuf_l2req_mask);

	reg[1:0]			selected_unit = 0;
	reg 				unit_selected = 0;

	assign icache_l2req_selected = selected_unit == 0 && unit_selected;
	assign dcache_l2req_selected = selected_unit == 1 && unit_selected;
	assign stbuf_l2req_selected = selected_unit == 2 && unit_selected;

	// L2 arbiter
	always @*
	begin
		case (selected_unit)
			2'd0:
			begin
				l2req_strand = icache_l2req_strand;
				l2req_unit = icache_l2req_unit;
				l2req_op = icache_l2req_op;
				l2req_way = icache_l2req_way;
				l2req_address = icache_l2req_address;
				l2req_data = icache_l2req_data;
				l2req_mask = icache_l2req_mask;
			end

			2'd1:
			begin
				l2req_strand = dcache_l2req_strand;
				l2req_unit = dcache_l2req_unit;
				l2req_op = dcache_l2req_op;
				l2req_way = dcache_l2req_way;
				l2req_address = dcache_l2req_address;
				l2req_data = dcache_l2req_data;
				l2req_mask = dcache_l2req_mask;
			end

			2'd2:
			begin
				l2req_strand = stbuf_l2req_strand;
				l2req_unit = stbuf_l2req_unit;
				l2req_op = stbuf_l2req_op;
				l2req_way = stbuf_l2req_way;
				l2req_address = stbuf_l2req_address;
				l2req_data = stbuf_l2req_data;
				l2req_mask = stbuf_l2req_mask;
			end
			
			default:
			begin
				// Don't care
				l2req_strand = {2{1'bx}};
				l2req_unit = {2{1'bx}};
				l2req_op = {3{1'bx}};
				l2req_way = {2{1'bx}};
				l2req_address = {26{1'bx}};
				l2req_data = {511{1'bx}};
				l2req_mask = {64{1'bx}};
			end
		endcase
	end
	
	assign l2req_valid = unit_selected && !l2req_ack;
	
	always @(posedge clk)
	begin
		if (unit_selected)
		begin
			// Check for end of send
			if (l2req_ack)
				unit_selected <= #1 0;
		end
		else
		begin
			// Chose a new unit		
			unit_selected <= #1 (icache_l2req_valid || dcache_l2req_valid || stbuf_l2req_valid);
			if (icache_l2req_valid)
				selected_unit <= #1 0;
			else if (dcache_l2req_valid)
				selected_unit <= #1 1;
			else if (stbuf_l2req_valid)
				selected_unit <= #1 2;
		end
	end
endmodule
