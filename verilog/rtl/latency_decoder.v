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

`include "instruction_format.h"

//
// This needs to agree with what is in the execute stage mux.
// XXX should this result just be pushed down the pipeline to avoid duplication
// of logic?
// 

module latency_decoder(
	input [31:0] instruction_i,
	output single_cycle_result,
	output multi_cycle_result);

	wire is_fmt_a = instruction_i[31:29] == 3'b110;
	wire is_fmt_b = instruction_i[31] == 1'b0;
	assign multi_cycle_result = (is_fmt_a && instruction_i[28] == 1)
		|| (is_fmt_a && instruction_i[28:23] == `OP_IMUL)	
		|| (is_fmt_b && instruction_i[30:26] == `OP_IMUL);	
	assign single_cycle_result = !multi_cycle_result && instruction_i != `NOP;
endmodule
