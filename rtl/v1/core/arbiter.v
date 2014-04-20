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
// Round robin arbiter.
// The incoming signal 'request' indicates units that would like to access some
// shared resource, with one bit per requestor.  The signal grant_oh (one hot) will 
// set one bit to indicate the unit that should receive access. grant_oh will be 
// available in the same cycle request is asserted.  If update_lru is set, this will 
// update its state on the next clock edge as follows:
// - If SWITCH_EVERY_CYCLE is set, this will select the next unit. The unit that 
//   was granted will not receive access again until the other units have an 
//   opportunity to access it.
// - If SWITCH_EVERY_CYCLE is 0, a unit will have acces to the resource until it
//   relenquishes it.
//
// Based on example from Altera Advanced Synthesis Cookbook.
//

module arbiter
	#(parameter NUM_ENTRIES = 4,
	parameter SWITCH_EVERY_CYCLE = 1)

	(input                      clk,
	input                       reset,
	input[NUM_ENTRIES - 1:0]    request,
	input                       update_lru,
	output[NUM_ENTRIES - 1:0]   grant_oh);

	logic[NUM_ENTRIES - 1:0] priority_oh_nxt;
	logic[NUM_ENTRIES - 1:0] priority_oh;
	logic[NUM_ENTRIES * 2 - 1:0] double_request;
	logic[NUM_ENTRIES * 2 - 1:0] double_grant;

	// Use borrow propagation to find next highest bit.  Double it to
	// make it wrap around.
	assign double_request = { request, request };
	assign double_grant = double_request & ~(double_request - priority_oh);	
	assign grant_oh = double_grant[NUM_ENTRIES * 2 - 1:NUM_ENTRIES] 
		| double_grant[NUM_ENTRIES - 1:0];

	generate
		if (SWITCH_EVERY_CYCLE)
		begin
			// rotate left
			assign priority_oh_nxt = { grant_oh[NUM_ENTRIES - 2:0], 
				grant_oh[NUM_ENTRIES - 1] };
		end	
		else
			assign priority_oh_nxt = grant_oh;
	endgenerate

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			priority_oh <= 1'b1;
		else if (request != 0 && update_lru)
			priority_oh <= priority_oh_nxt;
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


