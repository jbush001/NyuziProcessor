//
// 4 way pseudo-LRU
// The current state is represented by 3 bits.  Imagine a tree:
//
//        [1]
//       /   \
//    [0]     [2]
//   /   \   /   \
//  0     1 2     3
//
// The indices represent each the internal node, with 0 being left and 1
// being right.  We follow the path to the least recently used node.
//
// The combinational logic below has two independent functions, which are 
// combined into one module for convenience:
//  - Given the current value of the bits, return the index of the least
//    recently used item.
//  - Given the current value of the bits and an index, return the encoding
//    of the bits that would move that item to the LRU position.
//

module pseudo_lru(
	input [2:0]				lru_bits_i,
	output reg[1:0]			lru_index_o,
	input [1:0]				new_lru_index_i,
	output reg[2:0]			lru_bits_o);

	initial
	begin
		lru_index_o = 0;
		lru_bits_o = 0;
	end

	// Current LRU
	always @*
	begin
		casez (lru_bits_i)
			3'b00z: lru_index_o = 0;
			3'b10z: lru_index_o = 1;
			3'bz10: lru_index_o = 2;
			3'bz11: lru_index_o = 3;
		endcase
	end

	// Next LRU
	always @*
	begin
		case (new_lru_index_i)
			2'b00: lru_bits_o = { 2'b11, lru_bits_i[2] };
			2'b01: lru_bits_o = { 2'b10, lru_bits_i[2] };
			2'b10: lru_bits_o = { lru_bits_i[0], 2'b01 };
			2'b11: lru_bits_o = { lru_bits_i[0], 2'b00 };
		endcase
	end
endmodule

