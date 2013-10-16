// 
// Copyright 2013 Jeff Bush
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
// Collects statistics from various modules used for performance measuring and tuning.  
// Counts the number of discrete events in each category.
//
module performance_counters
	#(parameter	NUM_COUNTERS = 26)

	(input		clk,
	input 		reset,
	input[NUM_COUNTERS - 1:0] pc_event);
	
	localparam PRFC_WIDTH = 48;

	reg[PRFC_WIDTH - 1:0] event_counter[0:NUM_COUNTERS - 1];

	always @(posedge clk, posedge reset)
	begin : update
		integer i;
	
		if (reset)
		begin
			for (i = 0; i < NUM_COUNTERS; i = i + 1)
				event_counter[i] <= 0;

			/*AUTORESET*/				
		end
		else
		begin
			for (i = 0; i < NUM_COUNTERS; i = i + 1)
			begin
				if (pc_event[i])
					event_counter[i] <= event_counter[i] + 1;
			end
		end
	end
endmodule
