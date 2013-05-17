// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

//
// Round robin arbiter.
// The incoming signal 'request' indicates units that would like to access some
// shared resource, with one bit per requestor.  The signal grant_oh (one hot) will 
// set one bit to indicate the unit that should receive access. grant_oh will be 
// available in the same cycle request is asserted.  If update_lru is set, this will 
// update its state on the next clock edge so the unit that was granted will 
// not receive access again until the other units have an opportunity to access it.
// Based on example from Altera Advanced Synthesis Cookbook.
//

module arbiter
	#(parameter NUM_ENTRIES = 4)

	(input						clk,
	input						reset,
	input[NUM_ENTRIES - 1:0]	request,
	input						update_lru,
	output[NUM_ENTRIES - 1:0]	grant_oh);

	reg[NUM_ENTRIES - 1:0] next_priority_oh;

	// Use borrow propagation to find next highest bit
	wire[NUM_ENTRIES * 2 - 1:0]	double_request = { request, request };
	wire[NUM_ENTRIES * 2 - 1:0] double_grant = double_request 
		& ~(double_request - next_priority_oh);	
	assign grant_oh = double_grant[NUM_ENTRIES * 2 - 1:NUM_ENTRIES] 
		| double_grant[NUM_ENTRIES - 1:0];

	always @(posedge clk, posedge reset)
	begin
		if (reset)
			next_priority_oh <= 1;
		else if (request != 0 && update_lru)
			next_priority_oh <= { grant_oh[NUM_ENTRIES - 2:0], grant_oh[NUM_ENTRIES - 1] };	
			// Rotate left
	end
endmodule

