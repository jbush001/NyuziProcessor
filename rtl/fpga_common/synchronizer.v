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
// Transfer a signal between two clock domains, avoiding metastability.
//

module synchronizer
	#(parameter WIDTH = 1,
	parameter  	RESET_STATE = 0)

	(input						clk,
	input						reset,
	output logic[WIDTH - 1:0] 	data_o,
	input [WIDTH - 1:0] 		data_i);

	logic[WIDTH - 1:0] sync0;
	logic[WIDTH - 1:0] sync1;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			sync0 <= RESET_STATE;
			sync1 <= RESET_STATE;
			data_o <= RESET_STATE;
		end
		else
		begin
			sync0 <= data_i;
			sync1 <= sync0;
			data_o <= sync1;
		end
	end
endmodule
