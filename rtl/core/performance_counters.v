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


//
// Collects statistics from various modules used for performance measuring and tuning.  
// Counts the number of discrete events in each category.
//

module performance_counters
	#(parameter	NUM_COUNTERS = 1)

	(input                      clk,
	input                       reset,
	input[NUM_COUNTERS - 1:0]   perf_event);
	
	localparam PRFC_WIDTH = 48;

	logic[PRFC_WIDTH - 1:0] event_counter[NUM_COUNTERS];

	always_ff @(posedge clk, posedge reset)
	begin : update
		if (reset)
		begin
			for (int i = 0; i < NUM_COUNTERS; i++)
				event_counter[i] <= 0;
		end
		else
		begin
			for (int i = 0; i < NUM_COUNTERS; i++)
			begin
				if (perf_event[i])
					event_counter[i] <= event_counter[i] + 1;
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
