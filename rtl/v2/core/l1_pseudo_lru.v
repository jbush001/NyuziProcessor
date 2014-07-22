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
// Maintains a least recently used list for each cache set.
// Used to determine which way to replace when loading new cache lines.
//
// There are two ways the LRU is updated, each of which has a separate
// interface: fills and accesses (memory load instruction). The old contents 
// of the LRU must always be fetched before updating it (as they are stored in 
// SRAM, which has a cycle of latency).  
//
// Fill:
// When a response comes in from the L2 cache, fill_en/fill_set are asserted.
// One cycle later, this module will assert fill_way to indicate the least
// recently used way (which should be replaced). It will automatically move
// that way to the MRU.
//
// Access: 
// During normal processor memory loads, access_en/access_set are asserted 
// in the first cycle when a tag memory read request is performed.  One cycle 
// later, if there  was a cache hit, update_en/update_way are asserted to update 
// the accessed way to the MRU poition. It is illegal to assert update_en if
// access_en was not asserted a cycle earlier. If there was not a cache
// it, update_en is not asserted and LRU memory is not updated.
//
// If both fill_en and access_en are asserted simultaneously, fill
// will win.  This is important, both to prevent newly loaded lines from
// being evicted when there are many fills back to back and to avoid livelock
// in the worst case.
//

module l1_pseudo_lru
	#(parameter NUM_SETS = 1,
	parameter SET_INDEX_WIDTH = $clog2(NUM_SETS))
	(input                           clk,
	input                            reset,
	
	// Fill interface
	input                            fill_en,
	input [SET_INDEX_WIDTH - 1:0]    fill_set,
	output [1:0]                     fill_way,
	
	// Access interface
	input                            access_en,
	input [SET_INDEX_WIDTH - 1:0]    access_set,
	input                            access_update_en,
	input [1:0]                      access_update_way);
	
	logic[2:0] lru_flags;
	logic update_lru_en;
	logic [SET_INDEX_WIDTH - 1:0] update_set;
	logic[2:0] update_flags;
	logic [SET_INDEX_WIDTH - 1:0] read_set;
	logic read_en;
	logic was_fill;
	logic was_access;
	logic[1:0] new_mru;
	
	assign read_en = access_en || fill_en;
	assign read_set = fill_en ? fill_set : access_set;

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
	// *least recently used* element. A 0 stored in a node indicates the left node 
	// and a 1 the right. Each time an element is moved to the MRU, the bits along 
	// its path are set to the opposite direction.
	//
	sram_1r1w #(.DATA_WIDTH(3), .SIZE(NUM_SETS)) lru_data(
		// Fetch existing flags
		.read_en(read_en),
		.read_addr(read_set),
		.read_data(lru_flags),

		// Update LRU (from next stage)
		.write_en(update_lru_en),
		.write_addr(update_set),
		.write_data(update_flags),
		.*);
	
	// Output LRU for fill	
	always_comb
	begin
		casez (lru_flags)
			3'b00?: fill_way = 0;
			3'b10?: fill_way = 1;
			3'b?10: fill_way = 2;
			3'b?11: fill_way = 3;
		endcase
	end
	
	// Update flags
	assign new_mru = was_fill ? fill_way : access_update_way;
	assign update_lru_en = was_fill || access_update_en;
	
	always_comb
	begin
		unique case (new_mru)
			2'd0: update_flags = { 2'b11, lru_flags[0] };
			2'd1: update_flags = { 2'b01, lru_flags[0] };
			2'd2: update_flags = { lru_flags[2], 2'b01 };
			2'd3: update_flags = { lru_flags[2], 2'b00 };
		endcase
	end

	always_ff @(posedge clk, posedge reset)
	begin
		update_set <= read_set;
		was_fill <= fill_en;
		
		// It is a bug if something asserts access_update_en without asserting
		// access_en one cycle earlier.
		was_access <= access_en;	// Debug
		assert(!(access_update_en && !was_access));
	end
endmodule
