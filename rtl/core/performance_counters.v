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
	#(parameter	NUM_COUNTERS = 20)

	(input		clk,
	input 		reset,
	input[NUM_COUNTERS - 1:0] pc_event,
	
	// These are a bit special. One bit for each strand.
	input[3:0] 	pc_event_raw_wait,		
	input[3:0] 	pc_event_dcache_wait,
	input[3:0]	pc_event_icache_wait);
	
	integer i;

	localparam PRFC_WIDTH = 48;

	reg[PRFC_WIDTH - 1:0] event_counter[0:NUM_COUNTERS - 1];
	reg[PRFC_WIDTH - 1:0] raw_wait_count;
	reg[PRFC_WIDTH - 1:0] dcache_wait_count;
	reg[PRFC_WIDTH - 1:0] icache_wait_count;

	function count_bits;
		input[3:0] in_bits;
	begin
		count_bits = in_bits[0] + in_bits[1] + in_bits[2] + in_bits[3];
	end
	endfunction

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (i = 0; i < NUM_COUNTERS; i = i + 1)
				event_counter[i] <= 0;
				
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dcache_wait_count <= {PRFC_WIDTH{1'b0}};
			icache_wait_count <= {PRFC_WIDTH{1'b0}};
			raw_wait_count <= {PRFC_WIDTH{1'b0}};
			// End of automatics
		end
		else
		begin
			for (i = 0; i < NUM_COUNTERS; i = i + 1)
			begin
				if (pc_event[i])
					event_counter[i] = event_counter[i] + 1;
			end

			raw_wait_count <= raw_wait_count + count_bits(pc_event_raw_wait);
			dcache_wait_count <= dcache_wait_count + count_bits(pc_event_dcache_wait);
			icache_wait_count <= icache_wait_count + count_bits(pc_event_icache_wait);
		end
	end
endmodule
