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
// N-Way arbiter, with fairness.
// If PREEMPT is set, a new unit will be selected each cycle.  If not, a unit will be 
// selected until it de-asserts its request line, at which point it will not run again
// until all pending requestors have been granted.
//

module arbiter
	#(parameter NUM_ENTRIES = 4,
	parameter PREEMPT = 1)

	(input						clk,
	input[NUM_ENTRIES - 1:0]	request,
	input						update_lru,	// If we've actually used the granted unit, set this to one to update
	output[NUM_ENTRIES - 1:0]	grant_oh);

	reg[NUM_ENTRIES - 1:0] base = 1;
	wire[NUM_ENTRIES * 2 - 1:0]	double_request = { request, request };
	wire[NUM_ENTRIES * 2 - 1:0] double_grant = double_request & ~(double_request - base);
	assign grant_oh = double_grant[NUM_ENTRIES * 2 - 1:NUM_ENTRIES] 
		| double_grant[NUM_ENTRIES - 1:0];

	always @(posedge clk)
	begin
		if (|grant_oh && update_lru)
		begin
			if (PREEMPT)
				base <= #1 { grant_oh[NUM_ENTRIES - 2:0], grant_oh[NUM_ENTRIES - 1] };	// Rotate left
			else
				base <= #1 grant_oh;	
		end
	end
endmodule

