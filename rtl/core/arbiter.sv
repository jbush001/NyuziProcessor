// 
// Copyright 2011-2015 Jeff Bush
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
// The incoming signal 'request' indicates units that would like to access a 
// shared resource, with one bit per requestor.  The signal grant_oh (one hot)  
// sets one bit to encode the unit that is allowed access. grant_oh is not 
// registered and is valid the same cycle request is asserted. If update_lru is set, 
// this updates its state on the next clock edge and the unit that was granted will not 
// receive access again until the other units that are requesting access have a turn.
//

module arbiter
	#(parameter NUM_ENTRIES = 4)

	(input                           clk,
	input                            reset,
	input[NUM_ENTRIES - 1:0]         request,
	input                            update_lru,
	output logic[NUM_ENTRIES - 1:0]  grant_oh);

	logic[NUM_ENTRIES - 1:0] priority_oh_nxt;
	logic[NUM_ENTRIES - 1:0] priority_oh;

	localparam BIT_IDX_WIDTH = $clog2(NUM_ENTRIES);

	always_comb
	begin
		for (int grant_idx = 0; grant_idx < NUM_ENTRIES; grant_idx++)
		begin
			grant_oh[grant_idx] = 0;
			for (int priority_idx = 0; priority_idx < NUM_ENTRIES; priority_idx++)
			begin
				logic is_granted;
				
				is_granted = request[grant_idx] & priority_oh[priority_idx];
				for (logic[BIT_IDX_WIDTH - 1:0] bit_idx = priority_idx[BIT_IDX_WIDTH - 1:0]; 
					bit_idx != grant_idx[BIT_IDX_WIDTH - 1:0]; bit_idx++)
				begin
					is_granted &= !request[bit_idx];
				end

				grant_oh[grant_idx] |= is_granted;
			end
		end
	end

	// rotate left
	assign priority_oh_nxt = { grant_oh[NUM_ENTRIES - 2:0], 
		grant_oh[NUM_ENTRIES - 1] };

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			priority_oh <= 1;
		else if (request != 0 && update_lru)
		begin
			assert($onehot0(priority_oh_nxt));
			priority_oh <= priority_oh_nxt;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


