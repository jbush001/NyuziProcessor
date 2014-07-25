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
// Maintains least-recently-used list for each cache set to control cache line
// replacement. lru_way_o has one cycle of latency and will appear on the next 
// cycle after a set_i is asserted.
// update_mru and new_mru_way will apply to the set passed in the previous cycle,
// which is latched internally.  
//
// This uses a pseudo-LRU algorithm
// The current state of each set is represented by 3 bits.  Imagine a tree:
//
//        b
//      /   \
//     a     c
//    / \   / \
//   0   1 2   3
//
// The letters a, b, and c represent the 3 bits which indicate a path to the 
// least recently used element, with a 0 representing the left node and a 1 the
// right. Each time an element is moved to the MRU, the bits along its path are set 
// to the opposite direction.
//
// Used in both L1 and L2 caches.
//

module cache_lru
	#(parameter NUM_SETS = 32,
	parameter SET_INDEX_WIDTH = $clog2(NUM_SETS))

	(input                          clk,
	input                           reset,
	input                           access_i,
	input [1:0]                     new_mru_way,
	input [SET_INDEX_WIDTH - 1:0]   set_i,
	input                           update_mru,
	output logic[1:0]               lru_way_o);

	logic[2:0] old_lru_bits;
	logic[2:0] new_lru_bits;
	logic[SET_INDEX_WIDTH - 1:0] set_latched;

	sram_1r1w #(.DATA_WIDTH(3), .SIZE(NUM_SETS)) lru_data(
		.clk(clk),
		.read_addr(set_i),
		.read_data(old_lru_bits),
		.read_en(1'b1),
		.write_addr(set_latched),
		.write_data(new_lru_bits),
		.write_en(update_mru));

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			set_latched <= {SET_INDEX_WIDTH{1'b0}};
			// End of automatics
		end
		else
			set_latched <= set_i;
	end

	// Current LRU
	always_comb
	begin
		casez (old_lru_bits)
			3'b00?: lru_way_o = 0;
			3'b10?: lru_way_o = 1;
			3'b?10: lru_way_o = 2;
			3'b?11: lru_way_o = 3;
		endcase
	end

	// Next MRU
	always_comb
	begin
		unique case (new_mru_way)
			2'd0: new_lru_bits = { 2'b11, old_lru_bits[0] };
			2'd1: new_lru_bits = { 2'b01, old_lru_bits[0] };
			2'd2: new_lru_bits = { old_lru_bits[2], 2'b01 };
			2'd3: new_lru_bits = { old_lru_bits[2], 2'b00 };
		endcase
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
