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
// Array of cache valid bits.  Unlike sram_1r1w, this allows clearing the
// contents of the memory with the reset signal, which is necessary for
// proper operation of the cache.
//

module cache_valid_array
	#(parameter NUM_SETS = 32,
	parameter ADDR_WIDTH = $clog2(NUM_SETS))
	
	(input                    clk,
	input                     reset,
	
	input                     read_en,
	input[ADDR_WIDTH - 1:0]   read_addr,
	output logic              read_is_valid,
	input[ADDR_WIDTH - 1:0]   write_addr,
	input                     write_en,
	input                     write_is_valid);

	logic data[NUM_SETS];

	always_ff @(posedge clk, posedge reset)	
	begin : update
		if (reset)
		begin

`ifdef VERILATOR
			// - Verilator chokes on the non-blocking assignment here
			for (int i = 0; i < NUM_SETS; i++)
				data[i] = 0;
`else
			for (int i = 0; i < NUM_SETS; i++)
				data[i] <= 0;
`endif
			read_is_valid <= 0;
		end
		else
		begin
			if (read_en)
			begin
				if (write_en && read_addr == write_addr)
					read_is_valid <= write_is_valid;
				else
					read_is_valid <= data[read_addr];
			end

			if (write_en)
				data[write_addr] <= write_is_valid;
		end	
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
