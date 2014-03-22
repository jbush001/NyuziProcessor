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

`include "defines.v"

//
// Content addressable memory
//

module cam
	#(parameter NUM_ENTRIES = 2,
	parameter KEY_WIDTH = 32,
	parameter INDEX_WIDTH = $clog2(NUM_ENTRIES))
	
	(input                           clk,
	input                            reset,
	
	// Lookup interface
	input [KEY_WIDTH - 1:0]          lookup_key,
	output logic[INDEX_WIDTH - 1:0]  lookup_index,
	output                           logic                    lookup_hit,
	
	// Update interface
	input                            update_en,
	input [KEY_WIDTH - 1:0]          update_key,
	input [INDEX_WIDTH - 1:0]        update_index,
	input                            update_valid);

	logic[KEY_WIDTH - 1:0] lookup_table[0:NUM_ENTRIES - 1];
	logic[NUM_ENTRIES - 1:0] entry_valid;
	logic[NUM_ENTRIES - 1:0] hit_oh;

	genvar test_index;
	
	generate
		for (test_index = 0; test_index < NUM_ENTRIES; test_index = test_index + 1)
		begin : lookup
			assign hit_oh[test_index] = entry_valid[test_index] 
				&& lookup_table[test_index] == lookup_key;
		end
	endgenerate

	assign lookup_hit = |hit_oh;
	one_hot_to_index #(.NUM_SIGNALS(NUM_ENTRIES)) cvt(
		.one_hot(hit_oh),
		.index(lookup_index));
	
	always_ff @(posedge clk, posedge reset)
	begin : update
		if (reset)
		begin
			for (int i = 0; i < NUM_ENTRIES; i = i + 1)
			begin
				lookup_table[i] <= {KEY_WIDTH{1'b0}};	// Not strictly necessary
				entry_valid[i] <= 1'b0;
			end

			/*AUTORESET*/
		end
		else if (update_en)
		begin
			entry_valid[update_index] <= update_valid;
			lookup_table[update_index] <= update_key;		
		end
	end	

`ifdef SIMULATION
	// Test code checks for duplicate entries
	always_ff @(posedge clk)
	begin
		if (!reset && update_en)
		begin : test
			for (int i = 0; i < NUM_ENTRIES; i = i + 1)
			begin
				if (entry_valid[i] && lookup_table[i] == update_key
					&& i != update_index)
				begin
					$display("%m: added duplicate entry to CAM");
					$display("  original slot %d new slot %d", i, update_index);
					$finish;
				end
			end
		end
	end
`endif

endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
