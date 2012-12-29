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
// At the end of the execute stage, the single and multi-cycle pipelines merge
// at a mux.  This creates a hazard where an instruction can arrive at the end
// of both pipelines simultaneously. This module tracks instructions through the 
// pipeline and avoids issuing instructions that would conflict.  For each of the 
// instructions that could be issued, it sets a signal indicating if the instruction 
// would cause a conflict.
//

module execute_hazard_detect(
	input				clk,
	input				reset,
	input[3:0]			long_latency,
	input[3:0]			short_latency,
	input[3:0]			issue_oh,
	output[3:0]			execute_hazard);

	reg[2:0] writeback_allocate_ff;

	wire issued_is_long_latency = (issue_oh & long_latency) != 0;

	// This shift register tracks when instructions are scheduled to arrive
	// at the mux.
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			writeback_allocate_ff <= 3'h0;
			// End of automatics
		end
		else
			writeback_allocate_ff <= (writeback_allocate_ff << 1) | issued_is_long_latency;
	end
	
	assign execute_hazard = {4{writeback_allocate_ff[2]}} & short_latency;
endmodule



