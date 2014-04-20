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
// Convert a one-hot signal to a binary index corresponding to the active bit.
//

module one_hot_to_index
	#(parameter NUM_SIGNALS = 4,
	parameter INDEX_WIDTH = $clog2(NUM_SIGNALS))

	(input[NUM_SIGNALS - 1:0]         one_hot,
	output logic[INDEX_WIDTH - 1:0]   index);

	always_comb
	begin : convert
		index = 0;
		for (int index_bit = 0; index_bit < INDEX_WIDTH; index_bit++)
		begin
			for (int one_hot_bit = 0; one_hot_bit < NUM_SIGNALS; one_hot_bit++)
			begin
				if ((one_hot_bit & (1 << index_bit)) != 0)
					index[index_bit] = index[index_bit] | one_hot[one_hot_bit];
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

