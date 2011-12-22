//
// Maintains LRU for each cache set.  Note that this has one cycle of latency.
// update_mru and new_mru_way will apply to the set passed in the previous cycle.
//
// This uses a pseudo-LRU algorithm
// The current state is represented by 3 bits.  Imagine a tree:
//
//        [1]
//       /   \
//    [2]     [0]
//   /   \   /   \
//  0     1 2     3
//
// The indices indicate the path to the LRU element, with 0 being left and 1
// being right. 
//

module cache_lru
	#(parameter						SET_INDEX_WIDTH = 5,	
	parameter						NUM_SETS = 32)
	(input							clk,
	input [1:0]						new_mru_way,
	input [SET_INDEX_WIDTH - 1:0]	set_i,
	input							update_mru,
	output reg[1:0]					lru_way_o = 0);

	reg[2:0]						lru[0:NUM_SETS - 1];
	reg[2:0]						old_lru_bits = 0;
	reg[2:0]						new_lru_bits = 0;
	reg[SET_INDEX_WIDTH - 1:0]		set_latched = 0;
	integer							i;

	initial
	begin
		for (i = 0; i < NUM_SETS; i = i + 1)
			lru[i] = 0;
	end

	// Current LRU
	always @*
	begin
		casez (old_lru_bits)
			3'b00z: lru_way_o = 0;
			3'b10z: lru_way_o = 1;
			3'bz10: lru_way_o = 2;
			3'bz11: lru_way_o = 3;
		endcase
	end

	// Next MRU
	always @*
	begin
		case (new_mru_way)
			2'd0: new_lru_bits = { 2'b11, old_lru_bits[0] };
			2'd1: new_lru_bits = { 2'b01, old_lru_bits[0] };
			2'd2: new_lru_bits = { old_lru_bits[2], 2'b01 };
			2'd3: new_lru_bits = { old_lru_bits[2], 2'b00 };
		endcase
	end

	always @(posedge clk)
	begin
		set_latched <= #1 set_i;
		old_lru_bits <= #1 lru[set_i];

		// Note that we only update the LRU if there is a cache hit or a
		// read miss (where we know we will be loading a new line).  If
		// there is a write miss, we just ignore it, because this is no-write-
		// allocate
		if (update_mru)
			lru[set_latched] <= #1 new_lru_bits;
	end
endmodule
