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

`include "defines.v"

//
// Convert a one-hot signal to a binary index corresponding to the active bit.
//

module one_hot_to_index
	#(parameter NUM_SIGNALS = 4,
	parameter INDEX_WIDTH = `CLOG2(NUM_SIGNALS))

	(input[NUM_SIGNALS - 1:0]       one_hot,
	output logic[INDEX_WIDTH - 1:0]   index);

	always_comb
	begin : convert
		integer index_bit;
		integer one_hot_bit;
		
		index = 0;
		for (index_bit = 0; index_bit < INDEX_WIDTH; index_bit = index_bit + 1)
		begin
			for (one_hot_bit = 0; one_hot_bit < NUM_SIGNALS; one_hot_bit 
				= one_hot_bit + 1)
			begin
				if ((one_hot_bit & (1 << index_bit)) != 0)
					index[index_bit] = index[index_bit] | one_hot[one_hot_bit];
			end
		end
	end
endmodule
