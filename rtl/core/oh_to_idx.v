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

//
// Convert a one-hot signal to a binary index corresponding to the active bit.
// (Binary encoder)
// If DIRECTION is "LSB0", index 0 corresponds to the least significant bit
// If "MSB0", index 0 corresponds to the most significant bit
//

module oh_to_idx
	#(parameter NUM_SIGNALS = 4,
	parameter DIRECTION = "LSB0",
	parameter INDEX_WIDTH = $clog2(NUM_SIGNALS))

	(input[NUM_SIGNALS - 1:0]         one_hot,
	output logic[INDEX_WIDTH - 1:0]   index);

	always_comb
	begin : convert_gen
		index = 0;
		for (int oh_index = 0; oh_index < NUM_SIGNALS; oh_index++)
		begin
			if (one_hot[oh_index])
			begin
				if (DIRECTION == "LSB0")
					index |= oh_index[INDEX_WIDTH - 1:0];	// Use 'or' to avoid synthesizing priority encoder
				else
					index |= ~oh_index[INDEX_WIDTH - 1:0];
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

