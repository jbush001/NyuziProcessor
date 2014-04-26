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
// Convert a binary index to a one hot signal (Binary encoder)
// XXX should there be a parameter to control direction?
//

module index_to_one_hot
	#(parameter NUM_SIGNALS = 4,
	parameter INDEX_WIDTH = $clog2(NUM_SIGNALS))

	(output logic[NUM_SIGNALS - 1:0]       one_hot,
	input [INDEX_WIDTH - 1:0]              index);

	always_comb
	begin : convert
		one_hot = 0;
		for (int oh_index = 0; oh_index < NUM_SIGNALS; oh_index++)
		begin
			if (index == oh_index)
				one_hot[oh_index] = 1'b1;
		end
	end
endmodule
