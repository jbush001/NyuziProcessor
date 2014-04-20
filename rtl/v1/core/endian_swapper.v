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


// Convenience module to endian swap bytes in a word.  This is a module (despite
// its simplicity) so it can be used with array instantiation for wide signals.

module endian_swapper(
	input [31:0]    inval,
	output [31:0]   endian_twiddled_data);

	assign endian_twiddled_data = { inval[7:0], inval[15:8], inval[23:16], inval[31:24] };
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
