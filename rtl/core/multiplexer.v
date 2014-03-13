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
// Concatenated multiplexer. All of the inputs are concatenated into one port,
// so we can support a variable number of inputs.
//

module multiplexer
	#(parameter WIDTH = 32,
	parameter NUM_INPUTS = 2,
	parameter ASCENDING_INDEX = 0)
	
	(input [WIDTH * NUM_INPUTS - 1:0]                 in,
	input [$clog2(NUM_INPUTS) - 1:0]                  select,
	output [WIDTH - 1:0]                              out);

	logic[WIDTH - 1:0]                                 inputs[NUM_INPUTS - 1:0];

	genvar in_index;
	
	generate
		for (in_index = 0; in_index < NUM_INPUTS; in_index = in_index + 1)
		begin : update
			assign inputs[in_index]                         = in[in_index * WIDTH+:WIDTH];
		end
		
		if (ASCENDING_INDEX)
			assign out = inputs[(NUM_INPUTS - 1) - select]  ;
		else
			assign out = inputs[select]                     ;
	endgenerate
endmodule
