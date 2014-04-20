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
// Concatenated multiplexer. All of the inputs are concatenated into one port,
// so we can support a variable number of inputs.
//

module multiplexer
	#(parameter WIDTH = 32,
	parameter NUM_INPUTS = 2,
	parameter ASCENDING_INDEX = 0)
	
	(input [WIDTH * NUM_INPUTS - 1:0]                 in,
	input [$clog2(NUM_INPUTS) - 1:0]                  select,
	output [WIDTH - 1:0]                              out);

	logic[WIDTH - 1:0] inputs[NUM_INPUTS];

	genvar in_index;
	
	generate
		for (in_index = 0; in_index < NUM_INPUTS; in_index++)
		begin : update
			assign inputs[in_index] = in[in_index * WIDTH+:WIDTH];
		end
		
		if (ASCENDING_INDEX)
			assign out = inputs[(NUM_INPUTS - 1) - select];
		else
			assign out = inputs[select];
	endgenerate
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

