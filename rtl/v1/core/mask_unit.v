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
// Multiplexes on a per-byte basis between two sources.  Used to 
// bypass pending stores on L1 data cache accesses.  A 0 bit selects
// from data0_i and a 1 bit selects from data1_i
// 

module mask_unit(
	input             mask_i,
	input [7:0]       data0_i,
	input [7:0]       data1_i,
	output [7:0]      result_o);

	assign result_o = mask_i ? data1_i : data0_i;
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
