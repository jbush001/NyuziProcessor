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
// of both pipelines simultaneously (one would necessarily have to be dropped). 
// This module tracks instructions through the pipeline and avoids issuing 
// instructions that would conflict.  For each of the instructions that could be 
// issued, it sets a signal indicating if the instruction would cause a conflict.
// 

module execute_hazard_detect(
	input				clk,
	input[31:0] 		if_instruction0,
	input[31:0] 		if_instruction1,
	input[31:0] 		if_instruction2,
	input[31:0] 		if_instruction3,
	input[3:0]			issue_oh,
	output[3:0]			execute_hazard);

	wire[3:0]			single_cycle;
	wire[3:0]			multi_cycle;
	reg[2:0]			writeback_allocate_ff;
	reg					issued_is_multi_cycle;
	
	latency_decoder latency_decoder0(
		.instruction_i(if_instruction0), 
		.single_cycle_result(single_cycle[0]), 
		.multi_cycle_result(multi_cycle[0]));

	latency_decoder latency_decoder1(
		.instruction_i(if_instruction1), 
		.single_cycle_result(single_cycle[1]), 
		.multi_cycle_result(multi_cycle[1]));

	latency_decoder latency_decoder2(
		.instruction_i(if_instruction2), 
		.single_cycle_result(single_cycle[2]), 
		.multi_cycle_result(multi_cycle[2]));

	latency_decoder latency_decoder3(
		.instruction_i(if_instruction3), 
		.single_cycle_result(single_cycle[3]), 
		.multi_cycle_result(multi_cycle[3]));

	always @*
	begin
		if (issue_oh[0])
			issued_is_multi_cycle = multi_cycle[0];
		else if (issue_oh[1])
			issued_is_multi_cycle = multi_cycle[1];
		else if (issue_oh[2])
			issued_is_multi_cycle = multi_cycle[2];
		else if (issue_oh[3])
			issued_is_multi_cycle = multi_cycle[3];
		else 
			issued_is_multi_cycle = 0;
	end

	// This shift register tracks when instructions are scheduled to arrive
	// at the mux.
	always @(posedge clk)
		writeback_allocate_ff <= #1 (writeback_allocate_ff << 1) | issued_is_multi_cycle;
	
	assign execute_hazard = {4{writeback_allocate_ff[2]}} & single_cycle;
endmodule



