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
// Convert a one-hot signal to a binary index corresponding to the active bit.
//

module one_hot_to_index
	#(parameter NUM_SIGNALS = 4,
	parameter INDEX_WIDTH = $clog2(NUM_SIGNALS))

	(input[NUM_SIGNALS - 1:0] one_hot,
	output reg[INDEX_WIDTH - 1:0] index);

	always @*
	begin : convert
		integer i;
		
		index = 0;
		for (i = 0; i < NUM_SIGNALS; i = i + 1)
		begin
			if (one_hot[i])
				index = i;
		end
	end
endmodule
